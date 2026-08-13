---
description: Synthèse des 4 axes Codex (code, UX/parcours, copie/voix, design/accessibilité) sur la première ouverture — décisions produit tranchées, prêtes à devenir des beats testables.
---

# Bascule 4 — synthèse des 4 axes Codex (2026-08-13)

Premier exercice sous le mandat « Codex partout, au max » (Julien, 2026-08-13) : quatre axes lancés EN PARALLÈLE sur le même périmètre plutôt qu'une review unique. Ils ont convergé sur la structure et divergé sur un point, tranché ci-dessous.

## Axe CODE — REJET (traité)
Les callbacks passés par RÉFÉRENCE (`redirect: helper`, `builder: helper`) échappaient à la fermeture : un helper défini dans app.dart pouvait atteindre le shell sans owner dédié, d'autant qu'app.dart est exempté des scans de littéraux. Résolu : le checker résout la fonction nommée et analyse son corps comme s'il était inline (fixture de self-test).

## Axe UX — l'écran vide est un écran d'ACTION, pas d'absence
- Le passage landing → Aujourd'hui n'est PAS compréhensible aujourd'hui : « Éclaire ma situation » débouche sur « Commence par parler au coach » — changement de promesse, de vocabulaire et de canal.
- Ne JAMAIS exposer « mode local » comme destination produit : état technique, pas bénéfice.
- **Premier fait = DOMICILE FISCAL** : il conditionne réellement la fiscalité suisse, il est moins intrusif que le revenu, et il démontre que MINT contextualise. Ordre : domicile → état civil → revenu → affiliation LPP → versements 3a → marge attestée.
- **Pas de « 1/6 »** : recréerait le questionnaire et une dette de complétion. Progression QUALITATIVE (« premier repère », « ta situation se précise »), bénéfice observable après chaque réponse.
- **Le refus est un choix normal** : « Pas maintenant » ferme sans relance ; l'écran reste utilisable ; ne JAMAIS substituer automatiquement une autre question (questionnaire déguisé).
- 3 pièges : deux CTA menant au même endroit (faux choix) ; fausse personnalisation (cartes 3a/logement avant tout fait) ; collecte sérielle déguisée.

## Axe COPIE — tutoiement obligatoire, aucune promesse de résultat
- Le vouvoiement du cadrage CONTREDIT la voix du produit (app_fr.arb tutoie partout).
- « un fait à la fois » = jargon interne, à retirer.
- « Comprendre ta situation » sonne comme une promesse de résultat.

## Axe DESIGN — ouverture éditoriale, pas boîte d'erreur
- La landing n'est PAS un vestige : fond chaud, hero éditorial, cohérent. Gambarino porte la promesse, Fraunces les chiffres.
- MAIS : rétablir un point focal UNIQUE ; « Continuer sans compte » à supprimer visuellement s'il mène au même endroit que le CTA principal ; retirer le long-press caché sur le wordmark (non découvrable, inaccessible clavier/VoiceOver).
- État vide : eyebrow discret + phrase éditoriale Fraunces + UNE ligne de preuve honnête + UNE action pleine largeur. Reprendre la MATIÈRE du vertical 3a (porcelaine, bord fin, rayon 16, eyebrow, provenance) mais JAMAIS sa barre ni son chiffre sans données.
- Cibles tactiles ≥ 48×48 (les GestureDetector textuels sont sous la norme).
- Contrat sémantique runtime exigé : `screen:first_open.landing`, `node:first_open.promise`, `action:first_open.primary`, `action:first_open.login`, `screen:today.empty`, `node:today.empty_editorial`, `status:today.no_financial_facts`, `action:today.add_first_fact`, `node:first_open.beta_disclosure`.
- Un SEUL nœud sémantique par action (pas de wrapper + bouton enfant : annonces VoiceOver dupliquées). Ordre de lecture : promesse → état factuel → action.
- Gate accessibilité : identifiants présents, ordre VoiceOver stable, texte à 200 % sans troncature, Reduce Motion, contrastes AAA, activation par sémantique.

## DIVERGENCE TRANCHÉE — générique ou spécifique ?
Copie proposait une action générique (« Ajouter une information »), UX une action SPÉCIFIQUE avec justification (« Indiquer ton domicile fiscal » + « le canton et la commune changent les règles »). **Décision : SPÉCIFIQUE.** Le générique ramène au catalogue que l'axe UX identifie comme piège n°2, et prive l'utilisateur du « pourquoi » qui distingue MINT d'un formulaire. La voix reste celle de l'axe copie (tutoiement, aucune promesse).

## Copie retenue (tutoiement, LSFin-safe)
- Écran vide — eyebrow : « AUJOURD'HUI »
- Phrase éditoriale : « Ici commence ta situation. »
- Preuve honnête : « MINT ne sait encore rien de tes finances. »
- Justification : « Ton canton et ta commune changent les règles et ce que MINT peut te montrer. »
- Action principale : « Indiquer mon domicile fiscal »
- Action secondaire : « Pas maintenant »
- Après refus : « Aucun repère ajouté pour l'instant. Tu peux reprendre ici quand tu veux. » + action stable « Ajouter un premier repère »

## Contre-arguments / lacunes
- Contre-argument : commencer par le domicile plutôt que par le revenu retarde le premier chiffre — assumé : un chiffre affiché sans contexte fiscal serait une fausse précision, et l'axe UX rappelle qu'une estimation implicite est interdite.
- Lacune : le parcours de collecte du domicile existe déjà (Lego 1) mais son entrée depuis un Aujourd'hui VIDE n'est pas câblée — c'est le travail de la tranche T2.
- Lacune : la landing expose deux CTA vers la même destination ; les supprimer/différencier touche une surface hors périmètre B4 strict, à trancher au contrat amendé.
