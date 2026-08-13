#!/usr/bin/env bash
# Relecture Codex — permanente, mais routée et bornée.
#
# POURQUOI CE FICHIER EXISTE
#
# La relecture par un second modèle trouve réellement ce que les tests ratent :
# une recherche gardant la ponctuation qui manque « St. Gallen », un fichier de
# données tronqué pris pour valide, un écran mort sans reprise après un échec de
# lecture, une copie qui accuse la personne d'une faute qu'elle n'a pas faite,
# un crochet de pré-envoi qui ne lit pas ce que l'envoi contient. Elle doit donc
# rester permanente.
#
# Mais quatre axes sur chaque livrable, c'est la dépense dominante — et elle est
# largement gaspillée : lancer l'axe copie sur un changement de script Python ne
# trouve rien, lancer l'axe données sur un correctif de mise en page non plus.
#
# Ce script retire le choix des axes de mes mains. Ils se déduisent des chemins
# modifiés, mécaniquement. Trois règles gouvernent la dépense :
#
#   1. Le GRATUIT passe d'abord. Sans reçu de `tools/verify_full.sh`, aucune
#      relecture payante n'est lancée : payer un modèle pour relire un arbre
#      dont les tests échouent, c'est payer deux fois le même défaut.
#   2. Une seule batterie par lot de travail, sur la pointe candidate — jamais
#      à chaque commit.
#   3. Ce qu'une relecture payante trouve et qui est mécaniquement détectable
#      DOIT devenir un contrôle gratuit, pour ne plus jamais être payé.
#
# USAGE
#   tools/codex_axes.sh              # axes déduits du diff contre origin/dev
#   tools/codex_axes.sh --dry-run    # dit quels axes tourneraient, sans payer
#   tools/codex_axes.sh --base main  # autre base de comparaison

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO" || exit 1

BASE="origin/dev"
DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --base) shift; BASE="${1:-origin/dev}" ;;
  esac
  shift
done

PROMPTS="$REPO/tools/codex_prompts"
OUT_DIR="${TMPDIR:-/tmp}/codex-axes-$(git rev-parse --short HEAD)"

FILES="$(git diff --name-only "$BASE...HEAD" 2>/dev/null)"
if [ -z "$FILES" ]; then
  echo "Aucun fichier modifié contre $BASE — rien à relire."
  exit 0
fi

has() { echo "$FILES" | grep -qE "$1"; }

declare -a AXES=()

# CODE — tout changement de source ou de contrôle mécanique. C'est l'axe qui a
# trouvé les failles les plus coûteuses ; il ne se saute pas.
has '\.(dart|py|sh|ya?ml)$' && AXES+=("code")

# UX — un écran, un widget, une route : ce que quelqu'un traverse.
has '^apps/mobile/lib/(screens|widgets|routes)/' && AXES+=("ux")

# COPIE — ce qui est LU. Les fichiers de langue en font partie, et un écran
# aussi : la copie y est souvent inscrite avant d'être extraite.
has '^apps/mobile/lib/(l10n|screens|widgets)/|\.arb$' && AXES+=("copie")

# DONNÉES — calculs, modèles, migrations, référentiels, chargeurs. Le seul axe
# capable de voir qu'une clé d'identité manque ou qu'un référentiel vieillit.
has '^apps/mobile/lib/(data|models|services/financial_core)/|^services/backend/app/(services|models)/|^apps/mobile/assets/|migrations?/' && AXES+=("donnees")

if [ "${#AXES[@]}" -eq 0 ]; then
  echo "Aucun axe déclenché par ce diff — rien à payer."
  exit 0
fi

printf 'Axes déclenchés : %s\n' "${AXES[*]}"
printf 'Base : %s · %s fichier(s) modifié(s)\n' "$BASE" "$(echo "$FILES" | wc -l | tr -d ' ')"

if [ "$DRY" -eq 1 ]; then
  echo "(essai à blanc — rien lancé)"
  exit 0
fi

# LE GRATUIT D'ABORD. Un reçu absent ou périmé signifie que l'arbre n'a pas
# passé les contrôles déterministes ; le faire relire par un modèle payant
# reviendrait à acheter un diagnostic que la suite de tests donne pour rien.
if ! git rev-parse HEAD >/dev/null 2>&1 ||
   ! python3 tools/checks/verify_receipt_gate.py >/dev/null 2>&1; then
  echo
  echo "Relecture NON lancée : l'arbre n'a pas de reçu de vérification valable."
  echo "Le contrôle gratuit passe avant la relecture payante."
  echo "  Lancer d'abord :  tools/verify_full.sh"
  exit 1
fi

mkdir -p "$OUT_DIR"
DIFF_FILE="$OUT_DIR/diff.patch"
# Le diff seul, pas le dépôt : ce qu'on perd en contexte lointain, on le
# regagne en pouvoir d'en lancer plusieurs. Les axes qui ont besoin de lire un
# fichier entier le font eux-mêmes, le bac à sable est en lecture.
git diff "$BASE...HEAD" > "$DIFF_FILE"

for axis in "${AXES[@]}"; do
  prompt="$PROMPTS/$axis.md"
  if [ ! -f "$prompt" ]; then
    echo "Axe $axis ignoré : $prompt absent."
    continue
  fi
  {
    cat "$prompt"
    printf '\n\n---\nDIFF À RELIRE (base %s) :\n\n```diff\n' "$BASE"
    head -c 120000 "$DIFF_FILE"
    printf '\n```\n'
  } > "$OUT_DIR/$axis.prompt.md"
  (codex exec --sandbox read-only -C "$REPO" - \
      < "$OUT_DIR/$axis.prompt.md" > "$OUT_DIR/$axis.out.txt" 2>&1) &
done

wait
printf '\nSorties : %s\n' "$OUT_DIR"
for axis in "${AXES[@]}"; do
  [ -f "$OUT_DIR/$axis.out.txt" ] || continue
  verdict="$(grep -oE 'ACCEPT|REJET' "$OUT_DIR/$axis.out.txt" | tail -1)"
  printf '  %-10s %s\n' "$axis" "${verdict:-(sans verdict)}"
done
