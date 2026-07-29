---
description: Constat §3.5 du hand-off 2026-07-27 — la citation « CC art. 467-469 (réserves héréditaires) » de succession_divorce_bundle est fausse, vérifiée contre le droit et corroborée par trois sources internes du dépôt qui citent CC 470 ss. Correction en 3 occurrences, hors doctrine-atomicité, exécutable en unité de code.
---

# Constat — succession_divorce_bundle : la citation des réserves est fausse

Item §3.5 du hand-off `2026-07-27-HANDOFF.md` : « CC 467-469 y désigne les
réserves héréditaires ; ce sont les art. 470-471. Vérifier contre le texte de
loi — deux citations fausses ont déjà été corrigées cette semaine, une
suspicion a été infirmée. »

## 1. Ce que dit le bundle

`services/backend/app/services/coach/bundles/succession_divorce_bundle.py`
cite « CC art. 467-469 (réserves héréditaires) » à **trois** endroits :
lignes 11 (docstring), 29 (fragment) et 68 (corps doctrinal, « **Réserves
héréditaires (CC art. 467-469)** »).

## 2. Ce que dit le droit

Dans le Code civil suisse, titre des dispositions pour cause de mort :

- **art. 467** : capacité de disposer par testament (18 ans, discernement) ;
- **art. 468** : capacité de conclure un pacte successoral ;
- **art. 469** : nullité des dispositions entachées d'erreur, de dol ou de
  menace ;
- **art. 470** : quotité disponible — celui qui laisse des héritiers
  réservataires ne peut disposer que de ce qui excède leurs réserves ;
- **art. 471** : la réserve — depuis la révision du droit successoral entrée
  en vigueur le 1er janvier 2023, la moitié de la part successorale légale.

Les réserves héréditaires sont donc **CC art. 470-471**. Les art. 467-469
concernent la capacité de tester et les vices de volonté.

## 3. Corroboration interne — le bundle est isolé dans le dépôt

Trois surfaces du dépôt citent déjà correctement 470 ss :

| Où | Citation |
|---|---|
| `succession_simulator.py:401` | « a ete supprimee (CC art. 470 al. 1 rev.) » — suppression de la réserve des parents |
| `rag/faq_service.py:638` et `:647` | « Le CC suisse (art. 470) prévoit des réserves héréditaires… » · `legal_refs=["CC art. 470 ss", …]` |
| `rag/knowledge_catalog.py:571` | `legal_refs=["CC art. 470 ss"]` |

Le **contenu** substantiel du bundle est par ailleurs exact (réserve
descendante = ½ de la part légale depuis le 1.1.2023, ¾ avant) — seule la
référence d'articles est fausse.

## 4. Verdict

Citation fausse **confirmée** (la suspicion du hand-off tenait). Correction :
remplacer « 467-469 » par « 470-471 » aux trois occurrences. Le fichier n'est
pas dans la liste des six fichiers de doctrine du garde
`doctrine_atomicity_gate.py` (vérifié : CLAUDE.md, docs/AGENTS/{backend,
flutter}.md, 2 SKILL.md, 1 ADR) — la correction ne déclenche pas
l'atomicité. Unité de code exécutable, avec sonde : le prompt fragment
alimente le narrateur coach, donc citer la sortie du bundle avant/après dans
la PR suffit ; pas de surface d'écran directe.

## 5. Limites

- Vérification faite contre l'état du droit tel que connu (révision 2023) et
  la cohérence interne du dépôt, pas contre une consultation du Recueil
  systématique du jour. Deux citations du même bundle ont déjà été corrigées
  cette semaine — le reste du fragment (CC 462, 196 ss, 120-124…) n'a pas
  été re-vérifié ici, seule la question posée l'a été.
