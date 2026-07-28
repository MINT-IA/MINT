---
date: 2026-07-28
status: Proposed
authors: Claude (synthèse) — panel 3 experts (juriste LSFin/LSA, product coach, ingénieur)
panel: 3-pers + revue Codex
supersedes: —
superseded_by: —
description: La ligne n'oppose pas assurance et 3a — elle sépare l'impératif d'achat à prix nu (réécrit) de la description conditionnelle sourcée (conservée, prix déplacés du verbe vers le nom). Mécanisme — lint tri-stack à baseline-cliquet, vocabulaire partagé avec ComplianceGuard ; lint AVANT réécritures.
related:
  - .planning/architecture/2026-07-27-inventaire-prescriptions-produit.md
  - tools/checks/banned_terms_python.py
  - services/backend/app/services/coach/compliance_guard.py
---

# Prescriptions de produit : la ligne éditoriale et son mécanisme d'application

## TLDR

Ni interdiction générale ni statu quo : les impératifs d'achat à prix nu ou
paramètre de contrat sont réécrits en **description conditionnelle sourcée**
(la substance et les chiffres restent, déplacés du verbe vers le nom), et un
**lint tri-stack à baseline-cliquet** empêche la 17ᵉ occurrence — lint
d'abord, réécritures ensuite.

## Contexte

Inventaire 2026-07-27 (PR #1070) : 16 occurrences, 11 impératifs de
souscription dont 6 avec prix ou paramètre ; aucun garde sur ces surfaces ;
9 des 16 sont mobiles (hors de portée d'un garde backend). Le 2026-07-28,
Julien a délégué la décision au processus panel + Codex. Panel : trois
mémos, convergents sur le fond, complémentaires sur la forme.

## Décision

1. **La ligne** (juriste) : elle ne passe pas entre assurance et 3a — les
   assurances risque pur (IJM, APG, LAA, décès) sont hors du champ
   « conseil en placement » de la LSFin (pas des instruments financiers au
   sens de l'art. 3), et les règles de conduite assurantielles de la LSA
   visent les produits à caractère de placement. La ligne défendable
   sépare :
   - **à réécrire** : impératif d'achat + prix nu ou paramètre de contrat
     présenté comme le contrat à conclure (« Souscris une APG dès
     CHF 45/mois », « couverture d'au moins 720 jours », « versez le
     maximum ») — registre de promotion/recommandation, exposition
     exactitude (LCD) sur les chiffres non sourcés, et rupture du
     positionnement éducation qui est le bouclier du produit ;
   - **à conserver tel quel dans l'esprit** : description conditionnelle
     sourcée et datée d'une classe de produit, véhicules légaux et actes
     juridiques unilatéraux (3a, testament, désignation de bénéficiaire)
     formulés en actes de lucidité.
2. **Fait vérifié qui ferme le risque d'intermédiation** : MINT n'a aucun
   lien d'affiliation ni commission — c'est même un engagement affiché en
   6 langues (« Zéro commission. Zéro conflit. », « MINT ne perçoit aucune
   commission sur les produits mentionnés »). Le déclencheur LSA du juriste
   est écarté ; cet engagement devient une invariante à protéger.
3. **La formule éditoriale** (coach) : ① constat personnalisé de la lacune
   → ② conséquence chiffrée → ③ options existantes, **prix inclus comme
   information de marché, en fourchette sourcée et datée** → ④ verbe final
   = acte de lucidité (vérifier, comparer, décider), jamais d'achat. Le
   prix se déplace du verbe vers le nom : « une APG coûte typiquement dès
   CHF 45/mois » est une donnée ; « Souscris… dès CHF 45/mois » est une
   vente. Les 6 occurrences à prix conservent leurs chiffres — déplacés,
   pas supprimés. Checklists : l'impératif reste, son objet devient un
   acte de lucidité (« Vérifier ta couverture RC », pas « Souscrire une
   RC »). Les absolus inexacts (« sans IJM, tu n'as AUCUN revenu ») sont
   corrigés au passage.
4. **Le mécanisme** (ingénieur) : un lint source unique
   `tools/checks/product_prescription_lint.py` sur `.py` + `.dart` +
   `.arb` — pas de garde runtime sur du texte statique. **Baseline-cliquet**
   (patron `hmac_pepper_audit` : sites connus listés sans numéros de ligne,
   nouveau site = échec, entrée périmée = échec, la liste ne peut que
   rétrécir) plutôt que `--added-only` : la dette est de ~16-40 sites, pas
   des milliers. Motifs NFKC : `\bsouscri(?:s|re|vez)\b` ;
   `ouvr(e|ez|ir) un(e)? (compte|3e pilier)` ancré sur le véhicule ;
   `vers(e|ez|er) le maximum` ; motif prix `CHF \d+/mois` co-occurrent.
   Échappatoire : `lint-ignore: prescription` (grep-able, distinct de
   l'i18n). Un vocabulaire, deux points d'application (authoring-time pour
   le statique, runtime pour le LLM) — mais le **canonique vit côté
   backend** (`app/services/coach/prescription_vocab.py`) et c'est le LINT
   qui l'importe, pas l'inverse : le build Railway/Docker n'embarque que
   `services/backend/`, un import runtime depuis `tools/` casserait en
   production — classe d'échec déjà documentée dans `runtime_verb_gate.py`
   (revue Codex P1). Un test de parité CI verrouille lint ↔ vocabulaire.
5. **Séquencement** : lint d'abord (la barrière ne dépend pas des
   réécritures), réécritures ensuite jusqu'à baseline vide. Unités TDD :
   U1 motifs (16 chaînes de l'inventaire matchées, « la souscription
   d'une assurance » non matchée, évasion NFKC matchée) · U2 exemptions ·
   U3 cliquet · U4 `--self-test` + gate lefthook + CI · U5+ réécritures
   par surface avec la formule du coach.

## Counter-arguments and data gaps

- **Vue opposée la plus forte** : « changer le verbe ne change rien au
  fond — "vérifie ta couverture APG" accolé à un produit unique oriente
  autant qu'un impératif ». Le panel l'assume : ce qui tient la ligne
  n'est pas le verbe seul mais le triplet conséquence + alternative
  explicite (« ou décider d'assumer ce risque ») + chiffre sourcé. Le lint
  est nécessaire, pas suffisant ; la formule éditoriale complète est la
  vraie défense.
- **Porosité du lint** : « il te faut une IJM » évade les motifs — assumé,
  un lint fige des familles énumérées, pas la sémantique ; la liste ne
  peut que croître, et le Layer 2 runtime couvre le LLM.
- **Perte de punch** : la formule allonge les textes (+40 %) et une partie
  des utilisateurs préfère un ordre. Mitigation : constat-choc en première
  ligne. Data gap : aucune évidence A/B MINT-native ; les références
  (YNAB « educational software », Cleo constat-qui-pique) sont des marchés
  US/UK.
- **Gap juridique résiduel** : l'analyse s'appuie sur des sources
  secondaires convergentes ; le texte primaire de l'art. 3 LSFin et la
  circulaire FINMA 2025/2 n'ont pas été relus en intégralité — à faire
  avant de passer le statut à Decided.
