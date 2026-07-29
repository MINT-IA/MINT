---
date: 2026-07-28
status: Proposed
authors: Claude (synthèse) — panel 3 experts (fiscaliste successions/donations, fiscaliste immobilier + LAMal, product lead)
panel: 3-pers + revue Codex
supersedes: —
superseded_by: —
description: Socle 3-champs (statut/plage sourcée/mécanismes) pour succession+donation sur base ESTV 1.1.2025 ; modèle calibré ZH-VD-GE pour le gain immobilier + fix remploi prioritaire (méthode absolue ATF) ; LAMal frontalier recalibrée par PAYS DE RÉSIDENCE (gesamtbericht_eu 2026) — la table actuelle se trompe de population.
related:
  - .planning/architecture/2026-07-27-constat-succession-tax-table.md
  - .planning/architecture/2026-07-27-constat-donation-tax-table.md
  - .planning/architecture/2026-07-27-constat-housing-sale-plus-value.md
  - .planning/architecture/2026-07-27-constat-frontalier-base-rate-lamal.md
---

# Remplacements des tables succession, donation, gain immobilier et LAMal

## TLDR

Trois remplacements distincts : un **socle 3-champs par canton × catégorie**
(statut / plage sourcée / mécanismes) commun à succession et donation ; un
**modèle calibré** pour le gain immobilier là où le barème est statutaire
(ZH, VD, GE révisé 2025) avec **fix remploi prioritaire** ; une table LAMal
**par pays de résidence** — l'actuelle se trompe de population, pas
seulement d'étiquette.

## Contexte

Constats phase 1 (PR #1077-#1079) : tables plates indéfendables, écarts
prouvés (GE tiers ~54 % réels vs 26 % affiché ; ZH immobilier 0 % affiché
après 20 ans vs rabais plafonné à 50 % ; LAMal étiquetée franchise 300 sur
des moyennes toutes-franchises). Le 2026-07-28, Julien a délégué la
décision au processus panel + Codex. Le panel a de plus **corrigé deux
faits des constats** (voir Décision) — la phase 2 a rendu la phase 1 en
partie caduque, dans le bon sens : encore plus d'erreurs prouvées.

## Décision

### Succession + donation — un socle, deux calques

1. Remplacer les scalaires par un objet par canton × catégorie :
   `statut` ∈ {exonéré, taxé, taxé_lourd} (toujours renseignable) ·
   `plage` {min, max} **seulement si une source primaire la donne, sinon
   null** · `mecanismes` (franchise, centimes additionnels, communal,
   condition — ex. concubin ≥ 5 ans, linéaire|progressif) · `source`
   obligatoire.
2. **Source consolidée** : dossier ESTV « Impôts sur les successions et les
   donations », état 1.1.2025 — couvre le `statut` des 26 cantons ; c'est
   le plancher livrable en une unité. Plages chiffrées incrémentales
   (GE ~54 % centimes compris ; VS linéaire 10/15/25 % ; VD franchises
   300k donation / 1M succession).
3. **Faits durs corrigés par le panel** : seule l'exonération du
   **conjoint** tient 26/26. « Descendants exonérés » est faux comme
   généralisation — **VD, NE, AI** imposent la ligne directe, **LU** au
   niveau communal au-delà de 100k. Et la table donation inscrit LU à
   fratrie 8 %/tiers 25 % alors que **LU ne prélève aucun impôt sur les
   donations** (reprise < 5 ans dans la masse successorale) — erreur
   supplémentaire prouvée. OW/SZ : aucun impôt successoral.
4. **Forme à l'écran** (product) : verdict directionnel par catégorie +
   **variable de bascule** (« mariage ou pacte → exonération ») ; plage
   seulement si sourcée ; jamais de plage fabriquée depuis le défaut.
   L'alerte concubin garde son message, perd son taux plat.

### Gain immobilier — calibrer où c'est statutaire, mécanisme ailleurs

5. **Fix remploi en priorité absolue** : `_compute_remploi` applique la
   méthode proportionnelle écartée par le Tribunal fédéral (ATF 130 II
   202) — la méthode **absolue** s'impose (report seulement pour la part du
   réinvestissement excédant les coûts d'investissement du bien vendu),
   plus condition résidence principale et délai cantonal. Erreur jusqu'à
   100 % du report ; correctif algébrique, harmonisé LHID, sans calibrage
   cantonal — le meilleur ratio justesse/effort du lot.
6. **ZH : modèle calibré** — § 225 StG public et stable : 7 tranches
   progressives par gain (10 % → 40 %), majorations +50 %/+25 % (< 1 an /
   < 2 ans), rabais 5 % dès 5 ans puis 3 %/an plafonné à 50 %, seuil
   5'000 CHF. **VD : recalibrer** la forme plate par durée (légitime là-bas)
   avec le double comptage des années d'occupation personnelle. **GE :
   recalibrer sur la LCP révisée** — le 0 % après 25 ans est **mort depuis
   le 1.1.2025** (désormais 2 %) : le « seul zéro exact » du constat #1079
   était périmé, correction actée ici.
7. **BE/LU/BS + défaut** : plage sourcée + mécanisme + renvoi au
   calculateur cantonal officiel (quotités communales et tarifs revenus les
   rendent non-tabulables). Le garde `no_cantonal_rate_table` est amendé
   **consciemment** : les mécanismes paramétrés sourcés entrent en
   allowlist avec source et date ; les tables plates restent interdites.

### LAMal frontalier — changer de population, pas d'étiquette

8. La table actuelle est fausse **deux fois** : étiquette (moyennes
   toutes-franchises vendues comme franchise 300) et **population** — un
   frontalier paie la prime de son **pays de résidence** (France ≈ 200-300
   CHF/mois), pas celle du canton de travail (GE 580 encodé) : la
   comparaison LAMal/CMU affichée peut être **inversée**. Remplacement :
   table par pays de résidence (FR/DE/IT/AT) depuis le répertoire
   **`gesamtbericht_eu` de priminfo/OFSP, millésime 2026**, franchise 300
   adulte réelle, plage min-max inter-assureurs affichée, millésime à
   l'écran. Refresh annuel (publication OFSP fin septembre) + lint
   « millésime source = année de prime ».

### Priorisation (valeur/effort, product)

P1 suppression champ `base_rate` mort (trivial, aucune décision) ·
P2 fix remploi (justesse maximale, effort minimal) · P3 LAMal par pays de
résidence (vrai chiffre à portée de main, recommandation inversable
aujourd'hui) · P4 socle statut succession+donation (le plancher ESTV
26/26) · P5 ZH/VD/GE immobilier calibrés · P6 plages incrémentales.

## Counter-arguments and data gaps

- **Vue opposée la plus forte** : « des plages partout, housing compris,
  et pas de modèles calibrés » — refusé : une plage 0-50 % sur un gain de
  500k a 250k d'amplitude, inutilisable ; ZH est calibrable à coût borné.
  Inversement « recalibrer succession sur 26 lois » est refusé en phase 1 :
  le directionnel + statut ESTV livre la valeur maintenant, les plages
  s'ajoutent source par source.
- **Le tri-état perd de la précision** — assumé : directionnel vrai >
  précis faux (GE facteur ~2). VS prouve qu'un plat peut être juste —
  d'où le champ linéaire|progressif : le modèle interdit le plat **non
  sourcé sur un barème progressif**, pas le plat.
- **Data gaps** : plages chiffrées vérifiées en primaire pour GE, VD, VS,
  ZH, BE, LU, NW seulement — 19 cantons restent à sourcer avant affichage
  d'une plage ; l'assiette ZH > 20 ans (valeur vénale d'il y a 20 ans
  admissible, § 220 StG) fait de notre calcul une borne haute documentée ;
  les primes `gesamtbericht_eu` par pays n'ont pas encore été téléchargées
  (l'unité P3 commence par l'archivage du fichier source, patron
  collect_estv).
- **Risque éditorial** : « jusqu'à ~54 % » peut sonner alarmiste — toujours
  accolé au mécanisme et à la bascule, jamais en chiffre nu.
