# Price Report COB — récupération du 27.08.2026 et retour de la colonne « DE base »

Dossier de sauvetage. Le générateur du « Price Report COB » (rapport quotidien
EEX Suisse & Allemagne envoyé par Gmail à 05h40) a été construit le 26.08.2026
dans une session Claude Code **locale sur le Mac mini** (`fmv.local`), en
20 commits — **jamais poussés sur GitHub**. L'environnement de cette session a
été supprimé (« environment_deleted », irrécupérable côté cloud) : le script
n'existe donc que sur le Mac mini. Ce dossier versionne tout ce qui a pu être
reconstitué depuis les emails, pour que ça ne puisse plus disparaître.

## 1. Où vit la chaîne réelle (Mac mini)

- Déclenchement : launchd, autour de 05h35–05h41 les jours ouvrés
  (`sudo pmset repeat wakeorpoweron MTWRF 05:35:00` réveille le Mac).
- Entrée : mail « Price Report - EEX - Yearly » de `edm.office@fmv.ch`
  (pièce jointe `Price_Report_EEX_Yearly.xlsx`), arrivé vers 05h08.
- Sortie : mail HTML « Price Report COB — JJ.MM.AAAA » vers la boîte gmail,
  Bcc vers la boîte FMV, graphe `forme_du_jour.png` en pièce jointe inline
  (Content-ID `@fmv.local`).
- Sentinelle : à 11h33, mail d'alerte si aucun rapport n'est parti.
- Copie de développement : `~/Desktop/price-report-cob.nosync`.

Pour retrouver le script sur le Mac mini :

```bash
launchctl list | grep -i -e price -e report -e cob
grep -rl "Price Report COB" ~/Library/LaunchAgents/
# le .plist trouvé pointe vers le dossier d'installation réel
```

⚠️ **Ne pas exécuter `rm -rf ~/Desktop/price-report-cob.nosync`** (un des
« trois gestes » laissés en fin de session du 26.08) avant d'avoir localisé le
dossier d'installation réel ET poussé son contenu dans git. Tant que ce n'est
pas fait, ce dossier Desktop est possiblement la seule copie du code.

## 2. Le problème constaté le 27.08 au matin

La chaîne a bien tourné : source Robotron arrivée à 05h08, rapport
« Price Report COB — 26.08.2026 » parti à 05h40. Mais il a atterri **dans la
corbeille Gmail**, comme les deux exemplaires finaux du 26.08 au soir
(21h07 et 21h10). Tous les envois postérieurs à ~21h05 le 26.08 sont
auto-corbeillés — vraisemblablement un filtre Gmail créé en fin de session
(à vérifier dans Gmail → Paramètres → Filtres, chercher « Price Report COB »),
ou un nettoyage fait par la chaîne elle-même.

## 3. La colonne « DE base » (prix base Allemagne)

Présente dans les itérations du 26.08 jusqu'à 18h39, retirée ensuite au profit
des seuls spreads. À rétablir dans le tableau principal :

- position : 3ᵉ colonne du groupe « SPREADS », après CH−DE et PK−BL ;
- contenu : niveau BASE Allemagne en €/MWh, 2 décimales, virgule française ;
- source : feuille `DE` du xlsx Robotron, colonnes `M09_2026_BASE`,
  `M10_2026_BASE`, …, `Q04_2026_BASE`, …, `Y01_2027_BASE`, … (mêmes produits
  que la colonne CH) — PAS un calcul `CH − spread`, le spread affiché est
  arrondi à 1 décimale ;
- style : identique à la cellule PK−BL (12.5px, gris `#6b6b6b`, aligné à
  droite, fonds alternés) ;
- l'en-tête de groupe « SPREADS » passe de `colspan="2"` à `colspan="3"`.

Le correctif définitif se fait dans le générateur sur le Mac mini. En
attendant, `patch_report.py` applique les mêmes transformations en
post-traitement sur le HTML produit :

```bash
python3 patch_report.py rapport.html valeurs_de.json [fx.json] > rapport_patché.html
```

## 4. Tendance EUR/CHF dans l'en-tête

La ligne d'en-tête « EUR/CHF 0,9379 » devient :

```
EUR/CHF 0,9379 · 1j +0,14 % · 1m +0,87 % · 1an +0,09 %
```

Références (feuille `FX` du xlsx, jours calendaires, week-ends reportés —
prendre la valeur au plus proche à date ≤ cible) : veille cotée, même date
−1 mois, même date −1 an. Deltas en pourcentage, 2 décimales, virgule
française. Contrôle : les niveaux du 25.08 (0,9366) et du 26.08 (0,9379)
recoupent les en-têtes des rapports correspondants.

## 5. Piste ENTSO-E (prévisions, sans alourdir le rapport)

Le bloc Fondamentaux n'affiche que du réalisé. La Transparency Platform
ENTSO-E (API REST gratuite, jeton à demander une fois ; XML) fournit à
05h40 des prévisions pour le jour de livraison. Ajout suggéré : **une seule
ligne** « Prévu aujourd'hui » sous le bloc Fondamentaux, trois chiffres :

- éolien + solaire DE prévu (documentType `A69`, processType `A01`
  day-ahead / `A40` intraday, zone `10Y1001A1001A82H`) — le principal
  driver du spread CH−DE, à lire contre le réalisé de la veille déjà
  affiché ;
- charge DE prévue (documentType `A65`, processType `A01`) — ou CH selon
  la préférence, zone CH `10YCH-SWISSGRIDZ` ;
- nucléaire FR disponible (agrégation des indisponibilités REMIT,
  documentType `A80`/`A77`, zone `10YFR-RTE------C`) — la version
  prévisionnelle du « Nucléaire FR réalisé ».

Publication : day-ahead la veille vers 18h, intraday mis à jour dans la
nuit — tout est disponible au moment du run de 05h40. À éviter pour rester
léger : prévisions week-ahead, capacités transfrontalières, courbes
horaires complètes.

## 6. Contenu de `reference/`

| Fichier | Quoi |
|---|---|
| `2026-08-25_2102_final_sans_de_base.html` | Exemplaire final du 26.08 21h02 (layout de production, sans DE base), récupéré de Gmail |
| `2026-08-26_0540_envoye_sans_de_base.html` | Rapport auto du 27.08 05h40 (données COB 26.08), tel qu'envoyé |
| `2026-08-26_avec_de_base_et_fx.html` | **Cible** : le même rapport avec la colonne DE base rétablie et la tendance EUR/CHF (produit par `patch_report.py`) |
| `de_base_2026-08-26.json` | Les 14 niveaux BASE Allemagne du 26.08, extraits du xlsx Robotron |
| `fx_2026-08-26.json` | Niveau et tendance EUR/CHF du 26.08 (1j, 1m, 1an) |
| `eex_base_ch_de_2026-08-25_26.json` | Extraction CH + DE des 25 et 26.08 (contrôles croisés) |
| `forme_du_jour_2026-08-26.png` | Graphe joint au rapport du 05h40 |

Contrôles effectués : les valeurs DE du 25.08 extraites du xlsx coïncident
exactement avec la colonne « DE base » de la version 18h39 du 26.08
(Sep 26 = 136,90, …) ; les valeurs CH du 26.08 coïncident avec le rapport
parti à 05h40 (Q4 26 = 165,80) ; et `niveau CH − DE base` retombe sur le
spread CH−DE affiché, à l'arrondi près.

Note du 27.08 : le connecteur Gmail utilisé ici est lecture + envoi
uniquement (pas de droit de modification) — la restauration du rapport de
05h40 depuis la corbeille reste un geste manuel. Un exemplaire corrigé
(DE base + tendance FX) envoyé le 27.08 avec l'objet « Rapport prix COB — … »
est arrivé en boîte de réception sans être corbeillé, ce qui renforce
l'hypothèse d'un filtre sur l'objet exact « Price Report COB ».
