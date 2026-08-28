# Passation — implémenter le travail cloud dans le générateur (Mac mini)

Prompt à coller tel quel dans l'agent local (Codex / Claude Code) sur le
Mac mini. Autonome : il ne suppose aucun contexte de conversation.

---

Tu travailles sur le Mac mini de Julien, dans `~/price-report-cob` — la
chaîne du « Price Report COB » (rapport EEX quotidien envoyé par Gmail à
05h40 via les agents launchd `ch.fmv.pricereportcob*`). Le dépôt distant
est `github.com/Julienbatt/price-report-cob` (privé). Le travail
préparatoire — spécifications, scripts testés contre les vraies API,
maquettes cibles avec données réelles du 26.08 — vit sur la branche
`claude/prix-allemagne-rapport-q4ak2h` du repo `MINT-IA/MINT`, dossier
`tools/price_report_cob/`.

## Étape 0 — récupérer la spec

```bash
git clone --depth 1 -b claude/prix-allemagne-rapport-q4ak2h \
  https://github.com/MINT-IA/MINT /tmp/mint-spec
```

Lis `/tmp/mint-spec/tools/price_report_cob/README.md` EN ENTIER — c'est
la spec. Mets à jour `reference-cloud/` du dépôt local avec ce contenu
(il date d'une version antérieure de la branche).

## Étape 1 — à activer tout de suite (validé par Julien)

1. **Colonne « DE base »** dans le groupe SPREADS (README §3) — depuis la
   feuille `DE` du xlsx Robotron, jamais dérivée du spread arrondi.
2. **Tendance EUR/CHF** dans l'en-tête (README §4) — 1j / 1m / 1an depuis
   la feuille `FX`.

Implémente dans le générateur lui-même (pas en post-traitement) ;
`patch_report.py` de la spec sert de référence d'algorithme. Contrôle le
rendu contre `reference/2026-08-26_avec_de_base_et_fx.html` (mêmes
valeurs, données du 26.08).

## Étape 2 — derrière un drapeau de config, DÉSACTIVÉ par défaut

En attente de validation par Manfred — implémente, n'active pas :

3. **Colonne `peak` CH** en demi-teinte à côté de `base` + **ligne
   « Autres zones (base) »** FR/IT/AT sous le tableau (v2, README §7,
   cible `reference/2026-08-26_proposition_v2_digeste.html`).
4. **Étage ENTSO-E** (v3.1, README §8, cible
   `reference/2026-08-26_proposition_v3_fmv_entsoe.html`) :
   - spot FR et IT-Nord dans le bloc spot (A44, zones
     `10YFR-RTE------C` et `10Y1001A1001A73I`) ;
   - ligne « Flux frontaliers CH » de la veille (A11, 4 frontières × 2
     directions, GWh journaliers) ;
   - ligne « Prévu aujourd'hui » (A69 éolien+solaire DE, A65 charge
     DE/CH) sous les Fondamentaux ;
   - tendances Δ1j + moy. 7 j + écart sur les lignes « Nucléaire FR » et
     « Éolien + solaire DE » (A75, 8 jours d'historique) ;
   - suppression de la ligne orange des produits cotés d'un seul côté.

Points techniques ENTSO-E :
- `ENTSOE_TOKEN` est déjà dans `~/.config/fmv/secrets.env` — **source le
  coffre en tête de `scripts/lancer_quotidien.sh`** (launchd ne fournit
  pas l'environnement du shell).
- Compare `fondamentaux_entsoe.py` (chaîne) avec `entsoe_forecast.py`
  (spec) : vérifie le **piège curveType A03** — les points répétés sont
  omis (le solaire compresse ses zéros nocturnes), moyenner les points
  bruts surestime d'environ 19 % (48,9 au lieu de 41,1 GW mesuré le
  27.08). Garde une seule implémentation, correcte.

## Étape 3 — audit et vérification (obligatoire avant tout commit)

- **Dry-run complet sans envoi** du générateur sur les données du 26.08
  (respecte `state/envoi_autorise` / le mode test de la chaîne) ; diff du
  HTML produit contre les cibles de `reference/`.
- **Aucun secret** dans le diff ni dans l'historique (`git grep` sur les
  motifs password / token / UUID sur `$(git rev-list --all)`).
- **Aucune donnée EEX sous licence** ajoutée au suivi git — le
  `.gitignore` par formes (`reference/`, `*.html`, `report_data2*.json`)
  doit les attraper ; vérifie `git status` avant chaque commit.
- **La chaîne reste intacte** : plists launchd inchangés, les neuf
  scripts compilent, le rapport de demain 05h40 part comme d'habitude
  avec les seuls changements de l'étape 1 visibles.
- Commits atomiques (une fonctionnalité = un commit), push sur
  `origin/main` de `price-report-cob`.

## Compte rendu final attendu

Ce qui est activé, ce qui attend le drapeau, le résultat du dry-run
(diff vs cibles, écarts expliqués), et tout écart par rapport à la spec.
