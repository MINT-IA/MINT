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

# L'entrée CANONIQUE : le seul fichier produit autorisé à nommer un
# chemin legacy — tous les écrans passent par elle (intention explicite au
# point d'appel, pas seulement au redirect global).
CANONICAL_ENTRY_FILES = {
    "apps/mobile/lib/routes/legacy_onboarding_entry.dart",
    # Le registre DÉCLARE les chemins : les y nommer est sa fonction même,
    # pas un contournement. Exclusion STRUCTURELLE (un seul fichier, la
    # source de vérité), pas une allowlist de call-sites.
    "apps/mobile/lib/routes/route_metadata.dart",
}

# Répertoires exclus par CHEMIN (jamais du code produit).
EXCLUDED_PATH_PARTS = ("/test/", "/tests/", "/fixtures/", "/.dart_tool/")

# Le wizard navigue en interne entre ses propres écrans : exclusion par
# CHEMIN pour les NAVIGATIONS uniquement. Elle ne s'applique JAMAIS à la
# référence au symbole du shell : seul son fichier de DÉFINITION est
# exempté, sinon n'importe quel fichier du dossier pourrait l'instancier
# directement (P1 review T1).
WIZARD_INTERNAL_PREFIX = "apps/mobile/lib/screens/onboarding/"


@dataclass
class RouteNode:
    path: str
    builder: str | None = None
    redirect_targets: list[str] = field(default_factory=list)
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


def _balanced_extent(source: str, open_at: int) -> int:
    """Fin de l'expression ouverte à `open_at` — accolades/parenthèses
    équilibrées. Une regex non-gourmande tronquait un bloc à sa première
    `}`, ratant les returns situés après un `if { ... }` (P1 review #3)."""
    depth = 0
    index = open_at
    while index < len(source):
        char = source[index]
        if char in "{(":
            depth += 1
        elif char in "})":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return len(source)


# Un littéral de chemin, quel que soit le style de guillemets : Dart
# accepte les deux et n'en voir qu'un laissait passer `"/onb"` (P1 #3).
_PATH_LITERAL = re.compile(r"""['"](/[^'"]*)['"]""")


def _extract_redirect(window: str) -> list[str]:
    """TOUTES les cibles littérales d'un redirect, quelle que soit sa forme.

    Flèche simple, ternaire (les DEUX branches), bloc à plusieurs returns
    ou à branches imbriquées : on délimite l'expression par équilibrage
    puis on en extrait chaque littéral de chemin. Sur-approximer est SÛR
    ici — une cible en trop rend la fermeture plus conservatrice, jamais
    plus permissive.
    """
    match = re.search(r"redirect:\s*\([^)]*\)\s*(=>|\{)", window)
    if match is None:
        return []
    if match.group(1) == "{":
        body_start = window.index("{", match.end() - 1)
        body = window[body_start : _balanced_extent(window, body_start)]
        # Seules les valeurs RETOURNÉES sont des cibles : un littéral de
        # condition (`if (state.uri.path == '/profile')`) n'en est pas une
        # et créait un faux auto-cycle. Chaque expression retournée est
        # scannée entière, donc `return f ? '/a' : '/b';` donne les deux.
        returned = re.findall(r"return\s+([^;]*);", body)
        targets: list[str] = []
        for expression in returned:
            targets.extend(_PATH_LITERAL.findall(expression))
        return list(dict.fromkeys(targets))
    else:
        # Expression fléchée : jusqu'à la virgule de fin d'argument au
        # niveau 0 (les parenthèses internes sont équilibrées).
        rest = window[match.end() :]
        depth = 0
        cut = len(rest)
        for index, char in enumerate(rest):
            if char in "({[":
                depth += 1
            elif char in ")}]":
                if depth == 0:
                    cut = index
                    break
                depth -= 1
            elif char == "," and depth == 0:
                cut = index
                break
        body = rest[:cut]
    return list(dict.fromkeys(_PATH_LITERAL.findall(body)))


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
        redirect = _extract_redirect(window)
        nodes.append(
            RouteNode(
                path=path,
                builder=builder.group(1) if builder else None,
                redirect_targets=redirect,
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
            for target in node.redirect_targets:
                if target not in existing.redirect_targets:
                    existing.redirect_targets.append(target)

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
        return any(
            reaches_legacy(target, set(seen))
            for target in node.redirect_targets
        )

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
        source = _strip_comments(dart.read_text(encoding="utf-8"))
        if LEGACY_SHELL_SYMBOL in source:
            errors.append(
                f"{rel} references {LEGACY_SHELL_SYMBOL} outside the router"
            )
    return errors


def check_legacy_navigations(legacy_paths: set[str]) -> list[str]:
    """Grep CONSERVATEUR des navigations littérales vers un chemin legacy.

    Composant 4 du cadrage, conservé tel quel : une navigation produit
    vers /onb, /start ou un alias est signalée même si le redirect global
    la neutraliserait — le contrat exige la trace, pas seulement l'effet.
    Exclusions par CHEMIN (tests, fixtures, navigation interne au wizard,
    routeur) et par SYNTAXE (commentaires).
    """
    errors: list[str] = []
    # Tout LITTÉRAL de chemin legacy, quelle que soit sa forme d'usage :
    # `context.go('/onb')`, `onNavigate('/onb')`, `return '/onb';`,
    # `fallback: '/onb'`… Se limiter aux appels de navigation connus
    # laissait passer des callbacks et des valeurs de retour (P1 review
    # T1 #2) : l'entrée canonique restait contournable.
    literal = _PATH_LITERAL
    for dart in MOBILE_LIB.rglob("*.dart"):
        rel = str(dart.relative_to(ROOT))
        if any(part in f"/{rel}" for part in EXCLUDED_PATH_PARTS):
            continue
        if rel in CANONICAL_ENTRY_FILES:
            continue
        if rel.startswith(WIZARD_INTERNAL_PREFIX) or rel == "apps/mobile/lib/app.dart":
            continue
        source = _strip_comments(dart.read_text(encoding="utf-8"))
        for match in literal.finditer(source):
            if match.group(1).split("?")[0] not in legacy_paths:
                continue
            # Un endpoint HTTP qui partage le nom d'une route n'est PAS
            # une navigation : distinction SYNTAXIQUE par le verbe
            # d'appel immédiat, jamais par une liste de fichiers.
            before = source[max(0, match.start() - 24) : match.start()]
            if re.search(r"\b(?:post|get|put|patch|delete)\(\s*$", before):
                continue
            line = source[: match.start()].count("\n") + 1
            errors.append(
                f"{rel}:{line} names the legacy path {match.group(1)} — "
                "route it through LegacyOnboardingEntry"
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
    nav = re.compile(
        r"""context\.(?:go|push|replace)\(\s*['"](/[^'"]*)['"]"""
    )
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
        f"{n.path}|{n.owner}|{','.join(sorted(n.redirect_targets)) or n.builder or ''}"
        for n in report.nodes.values()
    )
    return hashlib.sha256("\n".join(normalized).encode()).hexdigest()


FINGERPRINT_FILE = ROOT / "product/mint_next/route_closure_fingerprint.json"


def read_expected_fingerprint() -> dict | None:
    if not FINGERPRINT_FILE.exists():
        return None
    return json.loads(FINGERPRINT_FILE.read_text(encoding="utf-8"))


def check_fingerprint(report: ClosureReport) -> list[str]:
    """L'empreinte du graphe est PERSISTÉE et comparée : une divergence
    signifie que le graphe de routes a bougé sans que le contrat le sache
    (P1 review T1 — une empreinte non comparée ne prouve rien)."""
    expected = read_expected_fingerprint()
    if expected is None:
        return [
            "no persisted route-closure fingerprint — run --write-fingerprint"
        ]
    actual = fingerprint(report)
    if expected.get("registry_fingerprint") != actual:
        return [
            "route graph fingerprint diverged from the persisted contract: "
            f"expected {expected.get('registry_fingerprint')}, got {actual} "
            "(re-run --write-fingerprint and justify the change)"
        ]
    return []


def run() -> ClosureReport:
    report = build_closure(
        APP_DART.read_text(encoding="utf-8"),
        REGISTRY_DART.read_text(encoding="utf-8"),
    )
    registered = set(parse_registry(REGISTRY_DART.read_text(encoding="utf-8")))
    legacy_paths = {p for p, n in report.nodes.items() if n.owner == LEGACY_OWNER}
    report.errors.extend(check_shell_references())
    report.errors.extend(check_legacy_navigations(legacy_paths))
    report.errors.extend(check_unregistered_navigations(registered))
    report.errors.extend(check_fingerprint(report))
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

    block_body = """
    GoRoute(
      path: '/onboarding/legacy-alias',
      redirect: (_, state) {
        MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/legit');
        return '/legit';
      },
    ),
""" + good_router
    blk = build_closure(block_body, registry)
    assert any("/onboarding/legacy-alias" in e for e in blk.errors), (
        "a block-bodied redirect reaching the shell must FAIL", blk.errors)

    ternary_router = """
    GoRoute(
      path: '/onboarding/ternary-alias',
      redirect: (_, __) => FeatureFlags.x ? null : '/legit',
    ),
""" + good_router
    tern = build_closure(ternary_router, registry)
    assert any("/onboarding/ternary-alias" in e for e in tern.errors), (
        "a ternary redirect reaching the shell must FAIL", tern.errors)

    multi_branch = """
    GoRoute(
      path: '/onboarding/multi-alias',
      redirect: (_, state) {
        if (state.uri.queryParameters.isEmpty) return '/home';
        return '/legit';
      },
    ),
""" + good_router
    multi = build_closure(multi_branch, registry)
    assert any("/onboarding/multi-alias" in e for e in multi.errors), (
        "a multi-branch redirect reaching the shell must FAIL", multi.errors)

    ternary_both = """
    GoRoute(
      path: '/onboarding/ternary-both',
      redirect: (_, __) => flag ? '/legit' : '/home',
    ),
""" + good_router
    tb = build_closure(ternary_both, registry)
    assert any("/onboarding/ternary-both" in e for e in tb.errors), (
        "a ternary whose FIRST branch reaches the shell must FAIL", tb.errors)

    double_quoted = """
    GoRoute(
      path: '/onboarding/double-quoted',
      redirect: (_, __) => "/legit",
    ),
""" + good_router
    dq = build_closure(double_quoted, registry)
    assert any("/onboarding/double-quoted" in e for e in dq.errors), (
        "a double-quoted redirect target must be seen", dq.errors)

    nested_block = """
    GoRoute(
      path: '/onboarding/nested-block',
      redirect: (_, state) {
        if (state.uri.queryParameters.isEmpty) {
          return '/home';
        }
        return '/legit';
      },
    ),
""" + good_router
    nb = build_closure(nested_block, registry)
    assert any("/onboarding/nested-block" in e for e in nb.errors), (
        "a return AFTER a nested if-block must be seen", nb.errors)

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
    if "--write-fingerprint" in sys.argv:
        payload = {
            "registry_fingerprint": fingerprint(report),
            "routes": len(report.nodes),
            "note": (
                "empreinte du graphe route -> owner -> redirect|builder ; "
                "toute divergence doit etre justifiee au contrat"
            ),
        }
        FINGERPRINT_FILE.write_text(
            json.dumps(payload, indent=2) + "\n", encoding="utf-8"
        )
        print(f"wrote {FINGERPRINT_FILE.relative_to(ROOT)}")
        return 0
    if "--fingerprint" in sys.argv:
        expected = read_expected_fingerprint() or {}
        print(json.dumps({
            "registry_fingerprint": fingerprint(report),
            "persisted_fingerprint": expected.get("registry_fingerprint"),
            "matches": expected.get("registry_fingerprint") == fingerprint(report),
            "routes": len(report.nodes),
        }))
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
