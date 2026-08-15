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
    --axe) shift; FORCE_AXE="${1:-}" ;;
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

# AXES DE MOMENT — plan (avant le code) et cloture (quand on prétend avoir
# fini). Ils ne se déduisent d'aucun diff : ils se demandent. Ajoutés le
# 2026-08-15, parce que la relecture ne couvrait que le milieu du travail.
if [ -n "${FORCE_AXE:-}" ]; then
  AXES=("$FORCE_AXE")
  printf 'Axe forcé : %s\n' "$FORCE_AXE"
fi
if [ "${#AXES[@]}" -eq 0 ]; then

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

fi

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
git diff "$BASE...HEAD" > "$DIFF_FILE"
DIFF_BYTES="$(wc -c < "$DIFF_FILE" | tr -d ' ')"

# PLAFOND ET TRONCATURE — la première version coupait le diff à 120 000 octets
# SANS LE DIRE. Sur un lot de 71 fichiers et 510 Ko, neuf fichiers arrivaient
# aux relecteurs, et le fichier au coeur du travail n'en faisait pas partie.
# Les verdicts portaient donc sur autre chose que ce que j'annonçais.
#
# Correctif : on n'envoie plus le diff en bloc. On envoie l'INVENTAIRE COMPLET
# des fichiers touchés — rien n'est invisible — et le diff n'est joint que
# s'il tient entier. Le bac à sable étant en lecture, chaque axe lit lui-même
# les fichiers dont il a besoin, ce qui coûte moins de jetons ET couvre tout.
DIFF_BUDGET=100000

for axis in "${AXES[@]}"; do
  prompt="$PROMPTS/$axis.md"
  if [ ! -f "$prompt" ]; then
    echo "Axe $axis ignoré : $prompt absent."
    continue
  fi
  {
    # Contexte permanent AVANT le mandat : Codex doit avoir le même niveau de
    # vue que Claude. Un axe borné trop étroitement ne rate pas un constat, il
    # en produit un FAUX (mesuré le 2026-08-14).
    [ -f "$PROMPTS/_contexte.md" ] && { cat "$PROMPTS/_contexte.md"; printf '\n\n---\n\n'; }
    cat "$prompt"
    printf '\n\n---\n## Ce qui a changé (base %s)\n\n' "$BASE"
    printf 'Le bac à sable est en LECTURE : ouvre toi-même les fichiers dont tu\n'
    printf 'as besoin. Ne te contente pas de ce qui est reproduit ci-dessous.\n\n'
    printf 'INVENTAIRE COMPLET — %s fichier(s) :\n\n```\n' \
      "$(echo "$FILES" | wc -l | tr -d ' ')"
    git diff --stat "$BASE...HEAD"
    printf '```\n\n'
    if [ "$DIFF_BYTES" -le "$DIFF_BUDGET" ]; then
      printf 'DIFF INTÉGRAL (%s octets) :\n\n```diff\n' "$DIFF_BYTES"
      cat "$DIFF_FILE"
      printf '\n```\n'
    else
      printf 'DIFF NON JOINT : %s octets, au-delà du plafond de %s. Aucun\n' \
        "$DIFF_BYTES" "$DIFF_BUDGET"
      printf 'extrait tronqué ne t'"'"'est servi — un diff coupé en son milieu\n'
      printf 'donnerait un verdict sur autre chose que le travail. Lis les\n'
      printf 'fichiers de l'"'"'inventaire ci-dessus, ils sont tous accessibles.\n'
    fi
  } > "$OUT_DIR/$axis.prompt.md"
  (codex exec --sandbox read-only -C "$REPO" - \
      < "$OUT_DIR/$axis.prompt.md" > "$OUT_DIR/$axis.out.txt" 2>&1) &
done

wait
printf '\nSorties : %s\n' "$OUT_DIR"
for axis in "${AXES[@]}"; do
  [ -f "$OUT_DIR/$axis.out.txt" ] || continue
  # LE VERDICT SE LIT À LA FIN, PAS N'IMPORTE OÙ (2026-08-15).
  #
  # La première version cherchait ACCEPT|REJET dans TOUTE la sortie. L'axe
  # clôture a conclu « NON FERMÉ » — un refus — et l'enveloppe a affiché
  # ACCEPT : le mot venait du journal des Legos cité dans le contexte, une
  # entrée vieille de deux jours, ligne 1443 sur 3900.
  #
  # Un refus presenté comme une acceptation ne rate pas un défaut : il en
  # fabrique un. C'est ce qui aurait autorisé une clôture fausse.
  #
  # Deux règles : on ne lit que la QUEUE, là où un verdict se pose ; et
  # « NON FERMÉ » l'emporte sur « FERMÉ », qu'il contient.
  verdict="$(tail -40 "$OUT_DIR/$axis.out.txt" \
    | grep -oE 'NON FERMÉ|FERMÉ|REJET|ACCEPT' | tail -1)"
  printf '  %-10s %s\n' "$axis" "${verdict:-(verdict illisible — LIRE la sortie)}"
done
