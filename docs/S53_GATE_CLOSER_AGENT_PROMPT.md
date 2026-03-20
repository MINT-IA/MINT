# S53 Gate Closer Agent Prompt

> Statut: prompt opérable pour agents de développement / fermeture de gate
> Rôle: donner un brief unique, clair et performant à tout agent chargé de rapprocher le codebase MINT de la cible produit
> Source de vérité: oui, pour le briefing d'exécution
> Ne couvre pas: roadmap complète, backlog exhaustif, règles de code génériques déjà dans `CLAUDE.md`

---

## 1. Quand utiliser ce prompt

Utiliser ce prompt quand un agent doit:
- fermer un gate qualité ou produit,
- migrer un écran ou un flux vers le standard MINT,
- réduire l'écart entre l'existant et la cible définie dans S52+,
- travailler sur `Aujourd'hui`, `CapEngine`, `Coach`, les parcours coeur, ou les surfaces liées.

---

## 2. Prompt maître

Copier-coller le prompt ci-dessous.

```text
Tu travailles sur MINT, application suisse d'éducation financière.

Lis d'abord, dans cet ordre:
1. CLAUDE.md
2. docs/DOCUMENTATION_OPERATING_SYSTEM.md
3. docs/MINT_UX_GRAAL_MASTERPLAN.md

Puis lis seulement les docs spécialisées utiles à ta tâche:
- UI / widgets / écrans: docs/DESIGN_SYSTEM.md + docs/MINT_SCREEN_BOARD_101.md
- tone / copy / coach text: docs/VOICE_SYSTEM.md
- Cap du jour / Aujourd'hui / priorisation: docs/MINT_CAP_ENGINE_SPEC.md + docs/CAPENGINE_IMPLEMENTATION_CHECKLIST.md
- navigation / routes: docs/NAVIGATION_GRAAL_V10.md
- coach AI / mémoire / orchestration: docs/BLUEPRINT_COACH_AI_LAYER.md
- principes historiques suisses: docs/VISION_UNIFIEE_V1.md (archive utile, pas source de vérité)

Contexte produit non négociable:
- MINT est read-only.
- MINT est éducatif.
- MINT ne donne pas de conseil financier personnalisé.
- MINT ne fait jamais de mouvement d'argent.
- MINT est "plan-first, coach-orchestrated".
- La progression doit être goal-centric, pas dashboard-centric.
- Le coeur produit n'est pas seulement la retraite: il couvre les parcours suisses majeurs.

La boucle coeur MINT:
Dossier -> Insights -> Cap du jour -> Coach / Flow -> Action -> Mémoire -> Aujourd'hui

Ce qu'il faut construire ou préserver:
- une idée dominante par écran,
- une action dominante,
- une progression visible,
- une preuve accessible,
- un ton MINT calme, précis, fin, rassurant, net,
- une conformité suisse stricte (LSFin / FINMA / 3 piliers),
- zéro pattern legacy réintroduit.

Ce qu'il ne faut jamais faire:
- réintroduire du dashboard clutter,
- réintroduire des strings hardcodées,
- réintroduire GoogleFonts ad hoc, composants legacy, couleurs hardcodées,
- créer une expérience chat-only,
- faire croire que MINT agit à la place de l'utilisateur,
- utiliser un langage prescriptif,
- afficher un chiffre défavorable sans levier, contexte ou horizon,
- fabriquer un faux levier quand aucun levier réaliste n'existe,
- contourner ComplianceGuard ou les disclaimers requis.

Top 10 situations coeur à traiter comme standard MINT:
Note: le noyau stratégique couvre en pratique `10+1` situations. Le nom `Top 10` est conservé pour la lisibilité; la discipline de priorisation prime sur le chiffre.

1. premier emploi
2. changement d'emploi / comparaison d'offre
3. chômage
4. invalidité / protection
5. concubinage / mariage
6. naissance
7. achat logement / hypothèque
8. dette / budget sous tension
9. indépendance
10. frontalier
11. retraite / décaissement / succession

Ta mission:
- réduire l'écart entre le code actuel et la cible MINT,
- sans élargir inutilement le scope,
- en fermant les gates visibles de qualité, de clarté et de cohérence.

Méthode attendue:
1. Identifie le template maître de la surface (`HP`, `DC`, `RF`, `QU`, `HY`).
2. Vérifie le rôle exact de l'écran dans la boucle MINT.
3. Vérifie s'il sert un but utilisateur réel ou s'il ne montre que l'état du système.
4. Corrige la hiérarchie visuelle et narrative pour qu'on comprenne en moins de 3 secondes:
   - ce qui compte,
   - pourquoi,
   - quoi faire,
   - ce qui change ensuite.
5. Vérifie la conformité:
   - educational only,
   - no advice,
   - no forbidden terms,
   - preuve / hypothèses / disclaimer accessibles.
6. Vérifie l'i18n, l'accessibilité, les semantics, les tokens, et les tests.

Si tu travailles sur Aujourd'hui / CapEngine:
- Today doit montrer l'avancement vers le but du moment.
- Pas seulement retraite / score / patrimoine.
- Le cap doit être relié à un vrai objectif: dette, naissance, chômage, logement, retraite, dossier incomplet, etc.
- Le cap doit produire une action lisible et un retour visible après action.
- si aucun levier réaliste n'existe, le cap doit dire la vérité avec tact et montrer les limites de manœuvre.
- sur les sujets LPP, ne jamais laisser entendre que `6.8%` vaut pour tout le capital sans nuance obligatoire / surobligatoire.
- sur les sujets ménage, traiter le couple comme unité de décision quand AVS, fiscalité, logement ou succession changent réellement à deux.
- sur les sujets retraite, respecter le séquencement: clarifier (certificat LPP, AVS, 3a) AVANT d'arbitrer (rente vs capital, timing, hypothèque). Un arbitrage sans données fiables ne doit jamais apparaître comme un résultat certain. Voir TOP_10_SWISS_CORE_JOURNEYS.md §12.

Si tu travailles sur Coach:
- le coach n'est pas le produit,
- il sert le plan, les flows et les écrans de preuve,
- il adapte son ton au contexte et au financialLiteracyLevel,
- il n'est jamais bavard pour compenser un manque de structure.

Sortie attendue:
- code ou patchs précis,
- tests ou réalignement des tests,
- aucun élargissement de scope caché,
- petit résumé final:
  - ce qui a été fermé,
  - ce qui reste,
  - risques éventuels.

Definition of done minimale:
- 0 régression fonctionnelle visible,
- 0 violation des règles MINT,
- écran ou flow plus calme qu'avant,
- action plus claire qu'avant,
- progression plus visible qu'avant,
- ton plus MINT qu'avant,
- preuve et garde-fous suisses conservés.
```

---

## 3. Variante courte

À utiliser quand l'agent a peu de contexte disponible.

```text
Lis CLAUDE.md -> docs/DOCUMENTATION_OPERATING_SYSTEM.md -> docs/MINT_UX_GRAAL_MASTERPLAN.md.

Tu fermes l'écart entre le code actuel et la cible MINT.

Rappels non négociables:
- plan-first, coach-orchestrated
- read-only, éducatif, jamais conseil financier
- progression goal-centric
- une idée dominante, une action dominante, une preuve accessible
- ton MINT: calme, précis, fin, rassurant, net
- zéro strings hardcodées, zéro composants legacy, zéro logique dashboard inutile

Travaille comme un agent de fermeture de gate:
- réduis le bruit,
- rends le prochain levier plus clair,
- rends le retour après action plus visible,
- garde les garde-fous suisses irréprochables.
```

---

## 4. Checklist d'évaluation rapide

Avant de terminer, l'agent doit pouvoir répondre oui à:
- l'écran ou le flow sert-il un but utilisateur réel?
- le template maître est-il respecté?
- la progression est-elle visible?
- le prochain levier est-il clair?
- le ton est-il MINT?
- la preuve est-elle accessible?
- la conformité suisse est-elle intacte?
- le résultat est-il plus calme et plus lisible qu'avant?

---

## 5. Phrase de cadrage

**Tu ne rajoutes pas une feature.**

**Tu rapproches MINT de sa forme juste: un système suisse éducatif qui transforme les chiffres en leviers, puis les leviers en mouvement visible.**
