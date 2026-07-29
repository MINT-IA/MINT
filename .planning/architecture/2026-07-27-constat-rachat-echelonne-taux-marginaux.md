---
description: Constat §3.1c du hand-off 2026-07-27 — TAUX_MARGINAUX_PAR_CANTON et _get_marginal_rate de rachat_echelonne_service sont du code mort prouvé par rejeu ; le chemin vivant calcule déjà par différence d'impôt du modèle v2. Suppression exécutable en une unité de code, sans décision de Julien.
---

# Constat — rachat_echelonne_service : la table de taux marginaux est morte

Unité §3.1c du hand-off `2026-07-27-HANDOFF.md`. Question posée : « supposé
code mort ; prouver l'absence d'appelant de `_get_marginal_rate` avant de
supprimer ». Le rapport d'agent est ici **rejoué et confirmé**, avec le
périmètre exact de la suppression.

## 1. La méthode n'a aucun appelant

```bash
grep -rn "_get_marginal_rate" services/backend/app services/backend/tests
```

Résultat du 2026-07-27 : cinq occurrences. Quatre appartiennent à
`coaching_engine.py` (définition `:384`, appels `:426`, `:480`, `:520`) — c'est
une méthode **homonyme** d'une autre classe, drainée séparément par la PR
#1063. La cinquième est la définition elle-même,
`rachat_echelonne_service.py:273`. Aucun appel.

Pas de dispatch dynamique non plus : aucune référence par chaîne dans
`app/calculators/_registry.py` ni dans `app/services/coach/` (grep
`"_get_marginal_rate"` sur ces arbres : zéro hit hors homonyme).

## 2. La table n'est lue que par la méthode morte

`TAUX_MARGINAUX_PAR_CANTON` (`rachat_echelonne_service.py:37`) a exactement un
lecteur applicatif : la ligne `:295` — **à l'intérieur de
`_get_marginal_rate`**. Idem pour `_DEFAULT_RATES` (`:67`), lu au même
endroit. La mort de la méthode entraîne celle des deux tables.

## 3. Le chemin vivant n'en a pas besoin

Depuis Beads MINT_nosync-81n/-97h (commentaire `:183-188`), le calcul
d'économie du plan de rachat passe par la **différence d'impôt du modèle v2**
(`estimate_income_tax`, interpolation 130 points) :

- plan annuel : `:193-201` ;
- comparaison bloc : `:224-229` ;
- l'override `taux_marginal_estime` fourni par l'appelant reste respecté
  (`:189-192`, `:222-223`).

L'ancienne approximation « montant × taux marginal moyen sur paliers » — celle
que la table servait — inversait la conclusion bloc/étalé vs le moteur mobile ;
c'est précisément pour cela qu'elle a été remplacée.

## 4. Périmètre exact de la suppression (unité de code suivante)

| À toucher | Quoi |
|---|---|
| `rachat_echelonne_service.py:37` | supprimer `TAUX_MARGINAUX_PAR_CANTON` (+ commentaire anti-résurrection) |
| `rachat_echelonne_service.py:67` | supprimer `_DEFAULT_RATES` |
| `rachat_echelonne_service.py:273-305` | supprimer `_get_marginal_rate` |
| `tests/test_lpp_deep.py:22` et `:267` | retirer l'import et l'assertion `len(...) == 26` — assertion de présence, le signal « un test vert ne prouve pas un fait du monde » (règle 3 du hand-off) |
| `tools/checks/no_cantonal_rate_table.py` | retirer l'entrée `rachat_echelonne_service.py::TAUX_MARGINAUX_PAR_CANTON` (le garde échoue sinon sur entrée inutile) |
| docstrings historiques | `endpoints/lpp_deep.py:77` et `tests/test_lpp_rachat_echelonne_grounding.py:13,164` racontent le KeyError historique `TAUX_MARGINAUX_PAR_CANTON[None]` — récit d'incident, peut rester tel quel |

Aucune décision de Julien requise : suppression de code mort, pas de nouvelle
formule ni constante (`rules.md` ASK FIRST non déclenché). Statut de l'unité :
🟡 → 🟢.

## 5. Limites du constat

- Le grep ne voit pas une réflexion du type `getattr(service, nom_calculé)` ;
  aucune trouvée, mais la recherche s'est bornée à `services/backend/`.
- L'assertion `len == 26` de `test_lpp_deep.py:267` passera au rouge à la
  suppression — c'est attendu et documenté ici, pas un golden à réécrire en
  silence.
