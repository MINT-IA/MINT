---
description: Constat §3.1b du hand-off 2026-07-27 — _MARGINAL_RATES_BY_CANTON de precision_service a DEUX consommateurs, pas un — l'alerte de cohérence Check 6 ET un SmartDefault taux_marginal (confiance 0.55, fallback 0.25). Écarts mesurés contre l'étalon ≤ 5,3 points ; des bascules d'alerte existent en bord de bande. Drain exécutable en une unité de code.
---

# Constat — precision_service : la table sert deux surfaces, pas une

Unité §3.1b du hand-off `2026-07-27-HANDOFF.md`. Question posée : « sert de
garde de cohérence sur la saisie (`:480`, `:747`) — établir l'effet sur
l'alerte affichée avant de toucher ».

## 1. La description du hand-off est incomplète : deux consommateurs

`_MARGINAL_RATES_BY_CANTON` (`precision_service.py:247`, 26 cantons × 3
tranches low/mid/high) est lue par :

1. **Check 6, alerte de cohérence** (`:478-511`) — si l'utilisateur saisit un
   `taux_marginal` inférieur à 0,5× ou supérieur à 1,6× la valeur de la table,
   un `CrossValidationAlert` de sévérité `warning` s'affiche (« semble bas » /
   « semble élevé »). Canton inconnu → `expected_rate = 0` → **aucune alerte,
   silencieusement**.
2. **`compute_smart_defaults`** (`:563` via `_estimate_marginal_rate` à
   `:744-748`) — la table **produit une valeur** : un `SmartDefault` pour le
   champ `taux_marginal`, confiance 0.55, avec un fallback **0.25 sans
   source** pour tranche ou canton inconnus. Ce n'est pas une garde ; c'est
   un chiffre par défaut proposé au profil.

## 2. Écarts mesurés contre l'étalon (2026-07-27)

Revenus représentatifs des tranches : 45k (low), 90k (mid), 150k (high).

| Canton | Tranche | Table | Étalon | Écart |
|---|---|---|---|---|
| ZH | mid | 0.28 | 0.2541 | +2,6 pts |
| ZH | high | 0.35 | 0.3221 | +2,8 pts |
| GE | low | 0.22 | 0.2560 | −3,6 pts |
| GE | high | 0.42 | 0.3667 | **+5,3 pts** |
| ZG | mid | 0.18 | 0.1714 | +0,9 pts |
| VD | high | 0.40 | 0.3938 | +0,6 pts |

Reproduction : boucle `estimate_marginal_rate(rev, canton)` sur ces couples
(script de session, valeurs recopiées telles quelles). Cette table est
nettement plus proche de l'étalon que celles drainées par #1061/#1063 — mais
elle reste une copie qui divergera, et sa granularité (3 tranches de 60k) est
grossière face à la pente continue.

## 3. Effet concret sur l'alerte affichée

Les bornes de la bande [0,5× ; 1,6×] bougent avec la valeur de référence.
Exemple mesuré, GE tranche high :

- table 0.42 → bande [0.21 ; 0.672] ;
- étalon 0.3667 → bande [0.183 ; 0.587].

Un utilisateur genevois à 150k qui saisit un taux marginal de 0.60 : **aucune
alerte aujourd'hui, « semble élevé » après drain**. Symétriquement, une saisie
de 0.20 déclenche « semble bas » aujourd'hui mais plus après drain. Les
bascules n'existent qu'en bord de bande ; le gros des saisies ne change pas
d'issue.

## 4. Effet sur le SmartDefault

La valeur préremplie `taux_marginal` changerait d'au plus ~5 points sur les
cas mesurés, et le fallback 0.25 disparaîtrait : l'étalon rend une valeur
dérivée du multiplicateur par défaut pour un canton inconnu (mesuré :
`estimate_marginal_rate(90000, "XX")` → 0.2625, pas d'exception). Le texte
`source` du SmartDefault (« Barèmes cantonaux approximatifs ») devra dire la
vraie provenance : pente du modèle calibré ESTV.

## 5. Verdict

Le drain est **exécutable en une unité de code** (statut 🟡 → 🟢), même patron
que #1061/#1063/#1064 : les deux consommateurs délèguent à
`estimate_marginal_rate`, la sémantique 0,5×/1,6× du Check 6 est conservée,
l'entrée du garde `precision_service.py::_MARGINAL_RATES_BY_CANTON` est
retirée. Pas de nouvelle formule ni constante — ASK FIRST non déclenché.
À signaler dans la PR d'implémentation : les deux effets visibles ci-dessus
(bascules d'alerte en bord de bande, valeur préremplie qui bouge).

## 6. Limites

- Mesures sur 4 cantons × 3 revenus, pas les 26 × N — l'écart max réel peut
  dépasser +5,3 pts sur un canton non mesuré.
- L'effet « alerte affichée » est établi sur le code du Check 6, pas re-prouvé
  sur simulateur ; la surface mobile qui rend `CrossValidationAlert` n'a pas
  été retracée ici.
