#!/usr/bin/env bash
# Vérification complète — et le reçu qui la prouve.
#
# POURQUOI CE FICHIER EXISTE
#
# Le 2026-08-13, deux fois dans la même session, j'ai annoncé « tests verts »
# après avoir lancé les tests des fichiers que je venais de toucher. La suite
# complète a ensuite montré 9 échecs, dont 7 causés par moi, dans des fichiers
# que je n'avais pas ouverts : des références visuelles de la landing, un test
# d'architecture qui LIT le code source comme du texte, un écran
# d'administration qui COMPTE les valeurs d'une enum partagée. Aucun de ces
# trois liens n'est visible dans un graphe d'appels.
#
# Le défaut n'était pas la qualité du code. C'était que **le périmètre de
# vérification était mon choix, et je l'ai choisi trop étroit**. La littérature
# nomme ce mode de défaillance « unsafe test selection » et « false success ».
#
# Le remède mesuré n'est pas une règle de discipline. Une instruction
# procédurale ajoutée à un fichier de doctrine déjà long est mesurée
# NETTE-NÉGATIVE : elle dilue les règles voisines, et un agent qui promet
# d'élargir son périmètre n'a toujours aucun moyen de savoir qu'un écran
# d'administration compte les valeurs de l'enum. Le remède est de retirer le
# choix : une seule commande, dont le périmètre est « tout », et un reçu
# machine que le crochet de pré-envoi vérifie.
#
# Sources : Huang et al., « LLMs Cannot Self-Correct Reasoning Yet » (ICLR
# 2024) ; Tyen et al., « LLMs cannot find reasoning errors, but can correct
# them given the error location » (ACL Findings 2024) — le déficit est dans la
# LOCALISATION, pas dans la volonté ; TDAD (arXiv:2603.17973) — la consigne
# procédurale sans carte d'impact fait passer les régressions de 6,08 % à
# 9,94 %, pire que rien ; Anthropic, Claude Code best-practices — « hooks are
# deterministic and guarantee the action happens », contrairement aux
# instructions de doctrine qui « sont consultatives ».
#
# USAGE
#   tools/verify_full.sh          # tout, puis écrit le reçu
#   tools/verify_full.sh --quick  # sans la suite mobile complète — N'ÉCRIT PAS
#                                 # de reçu, donc ne débloque aucun envoi
#
# L'arbre vérifié est celui de HEAD. Committer D'ABORD, vérifier ENSUITE : le
# reçu porte l'identifiant de l'arbre committé, ce qui rend impossible de
# vérifier un état puis d'en envoyer un autre.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO" || exit 1

RECEIPT_DIR="$REPO/.planning/.verify"
RECEIPT="$RECEIPT_DIR/receipt.json"
QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1

TREE="$(git rev-parse HEAD^{tree} 2>/dev/null)"
if [ -z "$TREE" ]; then
  echo "ÉCHEC — dépôt sans HEAD, rien à vérifier." >&2
  exit 1
fi

# Les gates lisent le RÉPERTOIRE DE TRAVAIL ; le reçu signe l'arbre COMMITTÉ.
# Tant que les deux diffèrent, le reçu attesterait un contenu qui n'a pas été
# exécuté — un correctif local non commité ferait passer les tests puis
# signerait un arbre qui ne le contient pas. Faille trouvée par la relecture
# adversariale de la première version.
DIRTY="$(git status --porcelain --untracked-files=normal)"
if [ -n "$DIRTY" ]; then
  echo "ÉCHEC — répertoire de travail modifié ; committer d'abord."
  echo "        Le reçu porte l'arbre COMMITTÉ ; vérifier un contenu et en"
  echo "        signer un autre n'attesterait rien."
  echo
  echo "$DIRTY" | head -20
  exit 1
fi

# Un crochet non installé ne se voit pas : le garde de pré-envoi ne tournerait
# tout simplement pas. On le dit, sans bloquer — le reçu reste valable, c'est
# la barrière qui manquerait.
if ! git config core.hooksPath >/dev/null 2>&1 && [ ! -f "$REPO/.git/hooks/pre-push" ]; then
  printf '\033[33mAvertissement : aucun crochet pre-push installé — le garde ne tournera pas. `lefthook install`.\033[0m\n'
fi

declare -a NAMES=()
declare -a CODES=()
FAILED=0

run_gate() {
  local name="$1"; shift
  printf '\n\033[1m▸ %s\033[0m\n' "$name"

  # UN CONTRÔLE ABSENT N'EST PAS UN CONTRÔLE ÉCHOUÉ (2026-08-15).
  #
  # Ce harnais a été porté sur une base reconstruite depuis dev, où quatre de
  # ses contrôles n'existent pas : ils appartiennent à la fondation du jumeau
  # et au Lego domicile, qui ne sont pas encore atterris.
  #
  # Les compter comme des échecs rendrait le reçu impossible ; les supprimer
  # rendrait le reçu MENTEUR — il affirmerait une couverture qu'il n'a pas.
  # On les déclare donc ABSENTS, et le récapitulatif le dit. Un vert n'a le
  # droit de prétendre qu'à ce qui a réellement tourné.
  # Le `-` compte comme un ARGUMENT, pas comme un fichier manquant : plusieurs
  # portes sont du python écrit en ligne (`python3 - <<'PY'`). La première
  # version de cette règle les a toutes déclarées ABSENTES — la parité des six
  # fichiers de langue n'a plus jamais tourné, en silence, dans un harnais dont
  # le seul métier est de ne pas mentir. Un contrôle qu'on croit couvert et qui
  # ne tourne pas est pire qu'un contrôle qu'on sait manquant.
  if [ "$1" = "python3" ] && [ -n "${2:-}" ] && [ "${2#-}" = "$2" ] \
     && [ ! -f "$2" ]; then
    # L'absence doit être DÉCLARÉE. Sinon supprimer un checker suffirait à le
    # faire taire, et l'absence deviendrait indistinguable du succès.
    if grep -qxF "$2" "$REPO/tools/checks/verify_absents.txt" 2>/dev/null; then
      NAMES+=("$name"); CODES+=("absent")
      printf '\033[33m  ABSENT (déclaré) — %s\033[0m\n' "$2"
      return 0
    fi
    NAMES+=("$name"); CODES+=("1")
    FAILED=1
    printf '\033[31m  ÉCHEC — %s a disparu sans être déclaré dans tools/checks/verify_absents.txt\033[0m\n' "$2"
    return 0
  fi

  "$@"
  local code=$?
  NAMES+=("$name")
  CODES+=("$code")
  if [ "$code" -ne 0 ]; then
    FAILED=1
    printf '\033[31m  ÉCHEC (%s) — %s\033[0m\n' "$code" "$name"
  else
    printf '\033[32m  ok\033[0m\n'
  fi
  return 0
}

flutter_analyze() { (cd apps/mobile && flutter analyze) ; }
flutter_tests()   { (cd apps/mobile && flutter test) ; }
backend_tests()   { (cd services/backend && python3 -m pytest tests/ -q) ; }

run_gate "analyse statique mobile"      flutter_analyze
[ "$QUICK" -eq 0 ] && run_gate "suite mobile COMPLÈTE" flutter_tests
run_gate "suite backend"                backend_tests
run_gate "garde Journey OS"             python3 tools/checks/journey_os_check.py
run_gate "gardes tous branchés"          python3 tools/checks/gardes_cables_check.py
run_gate "lint du wiki"                 python3 tools/checks/wiki_lint.py
run_gate "intégrité du registre des communes" \
         python3 tools/data/build_commune_registry.py --check
run_gate "discipline d'écriture du jumeau" \
         python3 tools/checks/twin_write_discipline.py
run_gate "dérivation de chaque fait du jumeau" \
         python3 tools/checks/twin_every_fact_is_derived.py
run_gate "couverture des tests par la CI" \
         python3 tools/checks/ci_test_coverage_gate.py
run_gate "auto-test du garde de reçu" \
         python3 tools/checks/verify_receipt_gate.py --self-test
run_gate "parité des 6 fichiers de langue" python3 - <<'PY'
import json, glob, sys
ref = {k for k in json.load(open('apps/mobile/lib/l10n/app_fr.arb')) if not k.startswith('@')}
bad = []
for path in sorted(glob.glob('apps/mobile/lib/l10n/app_*.arb')):
    keys = {k for k in json.load(open(path)) if not k.startswith('@')}
    missing = ref - keys
    extra = keys - ref
    if missing or extra:
        bad.append(f"{path}: {len(missing)} manquantes, {len(extra)} en trop")
for line in bad:
    print("  ", line)
sys.exit(1 if bad else 0)
PY

printf '\n\033[1m── récapitulatif ──\033[0m\n'
for i in "${!NAMES[@]}"; do
  printf '  %-42s %s\n' "${NAMES[$i]}" \
    "$(if [ "${CODES[$i]}" = "absent" ]; then echo "ABSENT"; elif [ "${CODES[$i]}" -eq 0 ]; then echo ok; else echo "ÉCHEC ${CODES[$i]}"; fi)"
done

if [ "$QUICK" -eq 1 ]; then
  printf '\n\033[33mMode rapide : aucun reçu écrit. Un envoi restera bloqué.\033[0m\n'
  exit "$FAILED"
fi

if [ "$FAILED" -ne 0 ]; then
  rm -f "$RECEIPT"
  printf '\n\033[31mAucun reçu : la vérification a échoué.\033[0m\n'
  exit 1
fi

if ! mkdir -p "$RECEIPT_DIR"; then
  echo "ÉCHEC — impossible de créer $RECEIPT_DIR" >&2
  exit 1
fi
TMP="$RECEIPT.tmp.$$"
{
  printf '{\n'
  printf '  "arbre": "%s",\n' "$TREE"
  printf '  "commit": "%s",\n' "$(git rev-parse HEAD)"
  printf '  "branche": "%s",\n' "$(git branch --show-current)"
  printf '  "verifie_le": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '  "gates": {'
  for i in "${!NAMES[@]}"; do
    [ "$i" -gt 0 ] && printf ','
    printf '\n    "%s": %s' "${NAMES[$i]}" "$(if [ "${CODES[$i]}" = "absent" ]; then echo '"absent"'; else echo "${CODES[$i]}"; fi)"
  done
  printf '\n  }\n}\n'
} > "$TMP"
if [ ! -s "$TMP" ] || ! mv -f "$TMP" "$RECEIPT"; then
  rm -f "$TMP" "$RECEIPT"
  echo "ÉCHEC — le reçu n'a pas pu être écrit ; aucun envoi ne sera débloqué." >&2
  exit 1
fi

printf '\n\033[32mReçu écrit : %s\033[0m\n' "${RECEIPT#$REPO/}"
printf 'Arbre vérifié : %s\n' "$TREE"
exit 0
