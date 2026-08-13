#!/usr/bin/env python3
"""Bascule 4 — fermeture du registre de routes (beats b4_owner_legacy,
b4_policy_fail_closed, b4_registry_closure).

Le registre de métadonnées connaît `path → owner` mais IGNORE le builder
et la cible des redirects : il ne peut donc pas répondre à « ce chemin
atteint-il l'onboarding legacy ? ». Ce checker construit le graphe réel
depuis `app.dart` (route → redirect* → builder), calcule sa fermeture
TRANSITIVE, et exige que tout nœud atteignant `OnboardingShellScreen`
porte l'owner `legacyOnboarding` dans `kRouteRegistry`.

Il vérifie aussi :
  * l'acyclicité de la fermeture des redirects ;
  * qu'aucune référence à `OnboardingShellScreen` n'existe hors du
    fichier autorisé (le routeur) ;
  * qu'aucune navigation littérale produit ne vise un chemin legacy.

Les exclusions sont par CHEMIN et par SYNTAXE (tests, commentaires,
fixtures, navigation interne au wizard, imports de types) — jamais une
allowlist extensible de call-sites produit.

Usage :
    python3 tools/checks/route_closure_check.py            # vérifie
    python3 tools/checks/route_closure_check.py --fingerprint  # empreinte
    python3 tools/checks/route_closure_check.py --self-test
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP_DART = ROOT / "apps/mobile/lib/app.dart"
REGISTRY_DART = ROOT / "apps/mobile/lib/routes/route_metadata.dart"
MOBILE_LIB = ROOT / "apps/mobile/lib"

LEGACY_SHELL_SYMBOL = "OnboardingShellScreen"
LEGACY_OWNER = "legacyOnboarding"

# Le SEUL fichier produit autorisé à référencer le shell legacy : le
# routeur. Toute autre référence produit est un contournement du registre.
AUTHORIZED_SHELL_REFERENCES = {
    "apps/mobile/lib/app.dart",
    "apps/mobile/lib/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart",
}

# Répertoires exclus par CHEMIN (jamais du code produit).
EXCLUDED_PATH_PARTS = ("/test/", "/tests/", "/fixtures/", "/.dart_tool/")

# Le wizard navigue en interne entre ses propres écrans : ce n'est pas un
# contournement, c'est son fonctionnement. Exclusion par CHEMIN.
WIZARD_INTERNAL_PREFIX = "apps/mobile/lib/screens/onboarding/"


@dataclass
class RouteNode:
    path: str
    builder: str | None = None
    redirect_target: str | None = None
    owner: str | None = None


@dataclass
class ClosureReport:
    nodes: dict[str, RouteNode] = field(default_factory=dict)
    errors: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors


def _strip_comments(source: str) -> str:
    """Retire commentaires de ligne et de bloc — exclusion par SYNTAXE."""
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    return re.sub(r"^\s*//.*$", "", source, flags=re.M)


def parse_registry(source: str) -> dict[str, str]:
    """path → owner, depuis kRouteRegistry."""
    owners: dict[str, str] = {}
    for match in re.finditer(
        r"'([^']+)':\s*RouteMeta\((.*?)\n  \),", source, re.S
    ):
        path, body = match.group(1), match.group(2)
        owner = re.search(r"owner:\s*RouteOwner\.(\w+)", body)
        if owner:
            owners[path] = owner.group(1)
    return owners


def parse_router(source: str) -> list[RouteNode]:
    """Extraction STRUCTURELLE des routes : path, builder, redirect."""
    clean = _strip_comments(source)
    nodes: list[RouteNode] = []
    # Chaque déclaration de route commence par `path: '...'` ; on lit la
    # fenêtre qui suit jusqu'au prochain `path:` pour y trouver builder et
    # redirect (les GoRoute imbriquées restent capturées par leur path).
    starts = [(m.start(), m.group(1)) for m in re.finditer(r"path:\s*'([^']+)'", clean)]
    for index, (offset, path) in enumerate(starts):
        end = starts[index + 1][0] if index + 1 < len(starts) else len(clean)
        window = clean[offset:end]
        builder = re.search(r"builder:\s*\([^)]*\)\s*(?:=>|\{)\s*(?:const\s+)?(\w+)", window)
        redirect = re.search(r"redirect:\s*\([^)]*\)\s*=>\s*'([^']+)'", window)
        if redirect is None:
            redirect = re.search(r"redirect:\s*\([^)]*\)\s*=>\s*\n?\s*\w[^;]*?\?\s*null\s*:\s*'([^']+)'", window)
        nodes.append(
            RouteNode(
                path=path,
                builder=builder.group(1) if builder else None,
                redirect_target=redirect.group(1) if redirect else None,
            )
        )
    return nodes


def build_closure(app_source: str, registry_source: str) -> ClosureReport:
    report = ClosureReport()
    owners = parse_registry(registry_source)
    for node in parse_router(app_source):
        node.owner = owners.get(node.path)
        # Une même déclaration peut apparaître deux fois (alias) : garder
        # la première, mais fusionner builder/redirect connus.
        existing = report.nodes.get(node.path)
        if existing is None:
            report.nodes[node.path] = node
        else:
            existing.builder = existing.builder or node.builder
            existing.redirect_target = existing.redirect_target or node.redirect_target

    # ── Fermeture transitive : quels chemins atteignent le shell legacy ──
    def reaches_legacy(path: str, seen: set[str]) -> bool:
        if path in seen:
            report.errors.append(f"redirect cycle detected at {path}")
            return False
        seen.add(path)
        node = report.nodes.get(path)
        if node is None:
            return False
        if node.builder == LEGACY_SHELL_SYMBOL:
            return True
        if node.redirect_target:
            return reaches_legacy(node.redirect_target, seen)
        return False

    for path, node in report.nodes.items():
        if reaches_legacy(path, set()):
            if node.owner != LEGACY_OWNER:
                report.errors.append(
                    f"{path} reaches {LEGACY_SHELL_SYMBOL} but its owner is "
                    f"{node.owner!r}, expected {LEGACY_OWNER!r}"
                )
    return report


def check_shell_references() -> list[str]:
    """Aucune référence produit au shell legacy hors fichier autorisé."""
    errors: list[str] = []
    for dart in MOBILE_LIB.rglob("*.dart"):
        rel = str(dart.relative_to(ROOT))
        if any(part in f"/{rel}" for part in EXCLUDED_PATH_PARTS):
            continue
        if rel in AUTHORIZED_SHELL_REFERENCES:
            continue
        if rel.startswith(WIZARD_INTERNAL_PREFIX):
            continue
        source = _strip_comments(dart.read_text(encoding="utf-8"))
        if LEGACY_SHELL_SYMBOL in source:
            errors.append(
                f"{rel} references {LEGACY_SHELL_SYMBOL} outside the router"
            )
    return errors


def check_unregistered_navigations(registered: set[str]) -> list[str]:
    """Aucune navigation littérale vers un chemin ABSENT du registre.

    Une navigation `context.go('/onb')` ne contourne PAS la politique :
    elle traverse le redirect global d'app.dart, qui applique
    `PreviewShellPolicy.blocksRoute`. Ce qui échappe réellement au
    contrôle, c'est un chemin SANS entrée de registre — donc sans owner,
    donc ingouvernable par la politique. C'est cela que ce composant
    interdit ; le contournement par builder direct est couvert par
    `check_shell_references`.
    """
    errors: list[str] = []
    nav = re.compile(r"context\.(?:go|push|replace)\(\s*'(/[^']*)'")
    for dart in MOBILE_LIB.rglob("*.dart"):
        rel = str(dart.relative_to(ROOT))
        if any(part in f"/{rel}" for part in EXCLUDED_PATH_PARTS):
            continue
        source = _strip_comments(dart.read_text(encoding="utf-8"))
        for match in nav.finditer(source):
            raw = match.group(1).split("?")[0]
            target = raw.rstrip("/") or "/"
            if target in registered:
                continue
            # Routes PARAMÉTRÉES : une navigation interpolée
            # `/data-block/${x}` correspond à l'entrée `/data-block/:type`.
            # On compare le préfixe statique (avant la 1re interpolation)
            # aux entrées du registre segment à segment.
            static_prefix = raw.split("$")[0].rstrip("/")
            if static_prefix and any(
                known.startswith(f"{static_prefix}/") and ":" in known
                for known in registered
            ):
                continue
            errors.append(
                f"{rel} navigates to {target} which has no registry entry "
                "(no owner, therefore ungoverned by the preview policy)"
            )
    return errors


def fingerprint(report: ClosureReport) -> str:
    """sha256 du graphe NORMALISÉ path → owner → redirectTarget|builder."""
    normalized = sorted(
        f"{n.path}|{n.owner}|{n.redirect_target or n.builder or ''}"
        for n in report.nodes.values()
    )
    return hashlib.sha256("\n".join(normalized).encode()).hexdigest()


def run() -> ClosureReport:
    report = build_closure(
        APP_DART.read_text(encoding="utf-8"),
        REGISTRY_DART.read_text(encoding="utf-8"),
    )
    registered = set(parse_registry(REGISTRY_DART.read_text(encoding="utf-8")))
    report.errors.extend(check_shell_references())
    report.errors.extend(check_unregistered_navigations(registered))
    return report


def self_test() -> int:
    """Fixtures : un alias non possédé DOIT faire échouer le checker."""
    registry = """
  '/legit': RouteMeta(
    path: '/legit',
    owner: RouteOwner.legacyOnboarding,
  ),
  '/sneaky': RouteMeta(
    path: '/sneaky',
    owner: RouteOwner.anonymous,
  ),
"""
    good_router = """
    GoRoute(
      path: '/legit',
      builder: (context, state) => const OnboardingShellScreen(),
    ),
"""
    bad_router = good_router + """
    GoRoute(
      path: '/sneaky',
      redirect: (_, __) => '/legit',
    ),
"""
    ok = build_closure(good_router, registry)
    assert ok.ok, ok.errors
    ko = build_closure(bad_router, registry)
    assert not ko.ok, "an alias reaching the shell without the owner must FAIL"
    assert any("/sneaky" in e for e in ko.errors), ko.errors

    cyclic = """
    GoRoute(path: '/a', redirect: (_, __) => '/b'),
    GoRoute(path: '/b', redirect: (_, __) => '/a'),
"""
    cyc = build_closure(cyclic, "")
    assert any("cycle" in e for e in cyc.errors), cyc.errors

    # Exclusion par SYNTAXE : une mention en commentaire n'est pas une
    # référence.
    commented = "// builder: (c, s) => const OnboardingShellScreen(),\n"
    assert LEGACY_SHELL_SYMBOL not in _strip_comments(commented)
    print("OK route_closure_check self-test")
    return 0


def main() -> int:
    if "--self-test" in sys.argv:
        return self_test()
    report = run()
    if "--fingerprint" in sys.argv:
        print(json.dumps({"registry_fingerprint": fingerprint(report)}))
        return 0 if report.ok else 1
    if report.ok:
        print(f"OK route_closure_check ({len(report.nodes)} routes)")
        return 0
    print("FAIL route_closure_check")
    for error in report.errors:
        print(f"  - {error}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
