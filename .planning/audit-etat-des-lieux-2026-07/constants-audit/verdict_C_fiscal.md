# Verdict — Groupe C (Fiscal) — Audit factuel constantes

> Bead `MINT_nosync-zaw`. Audité 2026-07-23. Méthode : lecture des fichiers source + vérification WebSearch/WebFetch contre sources officielles/comparables. Aucune valeur confirmée de mémoire. Vocabulaire verdict : **CONFORME** (correspond à l'officiel en vigueur) · **PÉRIMÉ** (correct par le passé, dépassé par réforme / progression à froid) · **INCORRECT** (faux vs officiel) · **DOUTEUX** (non vérifiable / simplification structurelle / source mal attribuée).

## Récapitulatif par verdict

| Verdict | LOT 1 (`group_C_fiscal.json`, 39) | LOT 2 (`cantonal_comparator.py`) |
|---|---|---|
| CONFORME | 5 | 0 |
| DOUTEUX | 34 | 1 (bloc `EFFECTIVE_RATES_100K_SINGLE`, 26 cantons) |
| PÉRIMÉ + INCORRECT | 0 | 1 (bloc `FEDERAL_BRACKETS`) |

**Total LOT 1** : 5 CONFORME · 34 DOUTEUX · 0 PÉRIMÉ · 0 INCORRECT.
**Total LOT 2** : 0 CONFORME · 1 DOUTEUX (26 taux) · 1 PÉRIMÉ+INCORRECT (barème IFD).

**Défaut transverse LOT 1** : les 39 entrées ont `valid_from` / `valid_until` **vides** et un `source_url` pointant vers une page d'accueil générique (`finma.ch/fr/`, `estv.admin.ch/`) — aucune ne cite une directive/barème précis. Non conforme à l'exigence « cite source ou registre de constantes » pour une donnée réglementaire.

---

## LOT 1 — `group_C_fiscal.json`

### Bloc `mortgage.*` (6) — règles ASB/FINMA

Format : `clé | valeur MINT | VERDICT | valeur officielle | source | validité`

| clé | valeur MINT | VERDICT | valeur officielle | source | validité |
|---|---|---|---|---|---|
| `mortgage.theoretical_rate` | 0.05 (5 %) | **CONFORME** | taux théorique 5 % pour le test de tenue des charges | ASB / Mendo / VZ | pratique en vigueur, dir. ASB rév. 2025 |
| `mortgage.maintenance_rate` | 0.01 (1 %) | **CONFORME** | ~1 % de la valeur pour frais d'entretien + accessoires dans le calcul de tenue | VZ / pratique bancaire | en vigueur |
| `mortgage.max_charge_ratio` | 0.3333 (1/3) | **CONFORME** | charges (intérêt théo. + amort. + entretien) ≤ 1/3 du revenu brut | ASB « règle du tiers » | en vigueur |
| `mortgage.min_equity` | 0.2 (20 %) | **CONFORME** | min. 20 % de fonds propres sur la valeur de nantissement | ASB dir. exigences min. | rév. en vigueur 01.01.2025 |
| `mortgage.max_2nd_pillar` | 0.1 (10 %) | **CONFORME** | ≥ 10 % de la valeur doit être des fonds propres **hors** 2e pilier → le 2e pilier ne peut couvrir que ≤ 10 % de la valeur | ASB dir. exigences min. | depuis 2012, maintenu |
| `mortgage.amortization_rate` | 0.01 (1 %) | **DOUTEUX** | la règle ASB n'est **pas** « 1 %/an » : amortir jusqu'à **2/3 (66,6 %) de la valeur de nantissement en 15 ans**, linéaire. 1 %/an est une approximation (ex. 80 %→66,6 % = 13,4 % sur 15 ans ≈ 0,89 %/an) | ASB dir. exigences min. | rév. en vigueur 01.01.2025 |

Sources : ASB directives (`swissbanking.ch` / miroir `finma.ch`), Mendo « nouvelles directives 2025 », VZ VermögensZentrum.
- <https://www.finma.ch/fr/~/media/finma/dokumente/dokumentencenter/myfinma/4dokumentation/selbstregulierung/sbvg_rl_hypofinanzierungen_20231213.pdf>
- <https://mendo.ch/fr/nouvelles-directives-sur-le-financement-hypothecaire-a-partir-de-2025/>
- <https://www.vermoegenszentrum.ch/fr/competences/un-bien-foncier-doit-etre-financierement-supportable>

### Bloc `capital_tax.*` scalaires + brackets (7)

| clé | valeur MINT | VERDICT | valeur officielle | source | validité |
|---|---|---|---|---|---|
| `capital_tax.default_rate` | 0.065 | **DOUTEUX** | source **mal attribuée** : LIFD art. 38 impose les prestations en capital **séparément à 1/5 du barème progressif art. 36** — ce n'est pas un taux plat de 6,5 %. 6,5 % est au mieux un effectif « tout compris » médian, non un chiffre art. 38 | LIFD art. 38 (fedlex) | art. 38 en vigueur |
| `capital_tax.married_discount` | 0.85 | **DOUTEUX** | aucun rabais « marié » uniforme de 15 % en droit fédéral ; le traitement marié/splitting varie par canton. Facteur inventé, non sourçable | — | non vérifiable |
| `capital_tax.bracket.0_100k` | 1.0 | **DOUTEUX** | échelle de progressivité forfaitaire inventée. Le fédéral (art. 38) = 1/5 du barème art. 36 (progressif) ; les cantons ont chacun leur barème. Un multiplicateur unique ne modélise pas la progressivité réelle (elle varie fortement d'un canton à l'autre : ZH ×1,47 de 100k→500k, SZ ×3,6, AI ×1,55) | calculsuisse (effectifs par canton) | 2026 |
| `capital_tax.bracket.100k_200k` | 1.15 | **DOUTEUX** | idem | idem | 2026 |
| `capital_tax.bracket.200k_500k` | 1.3 | **DOUTEUX** | idem | idem | 2026 |
| `capital_tax.bracket.500k_1m` | 1.5 | **DOUTEUX** | idem | idem | 2026 |
| `capital_tax.bracket.1m_plus` | 1.7 | **DOUTEUX** | idem | idem | 2026 |

### Bloc `capital_tax.cantonal.*` (26) — retrait en capital de prévoyance

**Verdict global : 26 × DOUTEUX.** Chaque canton = un **taux plat unique**, or les barèmes cantonaux de retrait en capital sont **fortement progressifs** selon le montant. Un taux plat sur/sous-estime selon le montant retiré et ne peut être « conforme » à aucun barème. De plus le champ est **notoirement volatil** (réformes 2024-2026) et MINT n'a ni date de validité ni source par canton. NB : la réforme fédérale du Conseil fédéral (« Programme d'allégement 27 », hausse dès 2027) a été **rejetée par le Conseil des États en 2025** — donc pas de choc fédéral, mais les barèmes cantonaux, eux, bougent.

Échantillon de 8 cantons — MINT (plat) vs effectifs vérifiés (fédéral+cantonal+communal, 2026, calculsuisse) :

| canton | valeur MINT (plat) | effectif réel @100k | effectif réel @500k | VERDICT | commentaire |
|---|---|---|---|---|---|
| ZH | 0.065 (6,5 %) | 4,88 % | 7,16 % | DOUTEUX | surestime à 100k, sous-estime à 500k |
| GE | 0.075 (7,5 %) | 4,13 % | 7,41 % | DOUTEUX | surestime fortement à 100k |
| VD | 0.080 (8,0 %) | 4,59 % | 8,39 % | DOUTEUX | surestime à 100k, sous-estime à 500k |
| VS | 0.060 (6,0 %) | 4,74 % | 8,78 % | DOUTEUX | sous-estime nettement à 500k |
| ZG | 0.035 (3,5 %) | 2,81 % | 5,76 % | DOUTEUX | sous-estime à 500k |
| BS | 0.075 (7,5 %) | 5,29 % | 9,45 % | DOUTEUX | sous-estime nettement à 500k |
| NE | 0.070 (7,0 %) | 5,68 % | 8,46 % | DOUTEUX | sous-estime à 500k |
| TI | 0.065 (6,5 %) | n/d (calculsuisse) | n/d | DOUTEUX | non vérifié numériquement, même défaut structurel |
| *(réf. SZ)* | *0.040* | *2,15 %* | *7,77 %* | — | **inversion de rang** : MINT classe SZ « bon marché » (4 %) mais SZ = 7,77 % à 500k (forte progressivité) |

Les 18 autres cantons (`BE, LU, UR, OW, NW, GL, FR, SO, BL, SH, AR, AI, SG, GR, AG, TG, JU`) : même verdict **DOUTEUX** par extension du défaut structurel (taux plat vs barème progressif, source/validité manquantes).

Sources retrait capital :
- <https://www.calculsuisse.ch/guides/imposition-retrait-capital-lpp-3a/>
- <https://www.vermoegenszentrum.ch/fr/comparatifs/impots-retrait-caisse-de-pension>
- <https://www.moneyland.ch/en/retirement-savings-withdrawal-tax-proposal-analysis-2025> (réforme fédérale)
- <https://www.klearconseils.ch/post/conseil-etats-bloque-hausse-impot-capital-lpp> (rejet Conseil des États 2025)

---

## LOT 2 — `services/backend/app/services/fiscal/cantonal_comparator.py`

### `FEDERAL_BRACKETS` (lignes 115-127) — barème IFD célibataire, LIFD art. 36

**Verdict : PÉRIMÉ (seuils) + INCORRECT (taux marginaux).** Double défaut.

**(a) Seuils = valeurs pré-2024** (avant compensation progression à froid). Le barème IFD officiel **2026** (personnes seules) est nettement plus haut :

| # | MINT (seuil / taux marg.) | Officiel 2026 (seuil / taux marg.) | seuil | taux marginal |
|---|---|---|---|---|
| 1 | 14 500 / 0,00 % | 15 200 / 0,00 % | PÉRIMÉ | ✓ |
| 2 | 31 600 / 0,77 % | 33 200 / 0,77 % | PÉRIMÉ | ✓ |
| 3 | 41 400 / 0,88 % | 43 500 / 0,88 % | PÉRIMÉ | ✓ |
| 4 | 55 200 / 2,60 % | 58 000 / 2,64 % | PÉRIMÉ | ~ (proche, faux) |
| 5 | 72 500 / 2,90 % | 76 200 / 2,97 % | PÉRIMÉ | ~ (proche, faux) |
| 6 | 78 100 / **5,10 %** | 82 100 / **5,94 %** | PÉRIMÉ | **INCORRECT** |
| 7 | 103 600 / **6,40 %** | 108 900 / **6,60 %** | PÉRIMÉ | INCORRECT |
| 8 | 134 600 / **6,80 %** | 141 500 / **8,80 %** | PÉRIMÉ | **INCORRECT (écart fort)** |
| 9 | 176 000 / **8,90 %** | 185 100 / **11,00 %** | PÉRIMÉ | **INCORRECT (écart fort)** |
| 10 | 755 200 / **11,00 %** | 794 000 / **13,20 %** | PÉRIMÉ | **INCORRECT (écart fort)** |
| 11 | ∞ / 11,50 % | ∞ / 11,50 % (taux max) | ✓ | ✓ |

**(b) Taux marginaux faux** : le barème art. 36 réel (stable depuis la réforme 2011, seuls les seuils bougent avec la progression à froid) est `0,77 / 0,88 / 2,64 / 2,97 / 5,94 / 6,60 / 8,80 / 11,00 / 13,20 / 11,50`. MINT diverge aux positions 6-10 (`5,10 / 6,40 / 6,80 / 8,90 / 11,00`) → **sous-estime l'IFD des revenus moyens-hauts** (ex. bracket 8 : 6,80 % au lieu de 8,80 % ; bracket 9 : 8,90 % au lieu de 11,00 %). Ce n'est pas de la dérive de progression à froid, ce sont des taux erronés.

Source : barème IFD 2026 personnes seules (seuils + taux marginaux) reproduit par kursor.ch ; barème primaire ESTV/AFC + compensation progression à froid 2026 (DFF).
- <https://www.estv.admin.ch/fr/deductions-taux-baremes-impot-federal-direct>
- <https://www.efd.admin.ch/fr/newnsb/VzaAUrhkPx2EPde4a6e3O> (compensation progression à froid 2026)
- <https://www.kursor.ch/impot-suisse> (barème 2026 détaillé)

Validité officielle : **année fiscale 2026** (2025 ≈ 0,1 % en dessous — l'IPC de compensation 2026 n'était que 0,1 %). Dans tous les cas les valeurs MINT (pré-2024) sont dépassées.

### `EFFECTIVE_RATES_100K_SINGLE` (lignes 32-60) — 26 cantons, échantillon 8

**Verdict global : DOUTEUX.**

Trois problèmes :
1. **Contradiction label/code.** Le docstring (l. 4-6) dit « total federal + cantonal + communal », mais `estimate_tax` (l. 245-257) ajoute l'IFD **séparément** via `FEDERAL_BRACKETS` et traite ce dict comme **cantonal+communal seul**. Donc soit le label est faux, soit l'IFD est **compté deux fois**. Défaut à trancher.
2. **Auto-étiqueté « simplifiés 2024/2026 »**, aucune table officielle citée par canton, pas de date de validité.
3. **Calibrage : compresse l'écart réel.** Lu comme cantonal+communal, MINT **surestime** les cantons bas et **sous-estime** les cantons hauts → un comparateur qui fait paraître les cantons plus proches qu'ils ne le sont (mine le but même du comparateur).

Échantillon 8 cantons — MINT vs effectif vérifié (célibataire, 100k, chef-lieu) :

| canton | MINT (dict) | effectif réel vérifié | VERDICT | commentaire |
|---|---|---|---|---|
| GE | 15,45 % | ~19,5 % total (dont ~17,5 % cant.+comm., ~2,0 % IFD) | DOUTEUX | sous-estime la part cantonale ~2 pts |
| VD | 14,89 % | ~18,5 % total (dont ~16,5 % cant.+comm.) | DOUTEUX | sous-estime ~1,6 pt |
| VS | 14,56 % | ~16,0 % total (dont ~14 % cant.+comm.) | DOUTEUX | proche (part cant. ≈ ok) |
| ZG | 8,23 % | Zoug/Baar ~4,4 % cant.+comm. @80k → ~5-6 % @100k | DOUTEUX | surestime ~2-3 pts la part cantonale |
| ZH | 12,90 % | ~9-10 % cant.+comm. @100k | DOUTEUX | surestime la part cantonale |
| BS | 15,78 % | chef-lieu haute imposition (>17 % total attendu) | DOUTEUX | non chiffré précisément, plafond MINT bas |
| NE | 14,23 % | Neuchâtel haute imposition (>16 % cant.+comm. attendu) | DOUTEUX | sous-estime |
| TI | 13,56 % | non chiffré (source) | DOUTEUX | non vérifié |

Note : les mentions « >22 % à 100k » vues sur plusieurs blogs sont des taux **marginaux**, pas effectifs — le total effectif GE @100k est ~19,5 % (calculsuisse), cohérent avec un effectif, pas 22 %.

Sources :
- <https://www.calculsuisse.ch/guides/impots-geneve-vaud-valais/> (GE ~19,5k / VD ~18,5k / VS ~16k total @100k, 2026)
- <https://www.calculsuisse.ch/guides/charge-fiscale-26-cantons/>
- <https://www.zh.ch/content/dam/zhweb/bilder-dokumente/themen/steuern-finanzen/kantonsfinanzen/steuerbelastungsmonitor/BAK%20Economics_Z%C3%BCrcher_Steuerbelastungsmonitor_2025.pdf> (BAK Steuerbelastungsmonitor 2025)

---

## PÉRIMÉES / DOUTEUSES — corrections proposées

### PÉRIMÉ + INCORRECT (1 bloc, priorité haute)

**`FEDERAL_BRACKETS`** — remplacer par le barème IFD officiel personnes seules **année fiscale 2026** (seuils compensés + taux marginaux corrects) :

```
FEDERAL_BRACKETS = [
    (15_200, 0.0000),
    (33_200, 0.0077),
    (43_500, 0.0088),
    (58_000, 0.0264),
    (76_200, 0.0297),
    (82_100, 0.0594),
    (108_900, 0.0660),
    (141_500, 0.0880),
    (185_100, 0.1100),
    (794_000, 0.1320),
    (float("inf"), 0.1150),   # taux moyen max plafonné à 11,5 %
]
```
Ajouter `valid_from = 2026-01-01` et re-sourcer sur le barème ESTV/AFC (pas une page d'accueil). Prévoir une revue annuelle (compensation progression à froid). Corriger aussi le commentaire « 2024/2026 » → année fiscale précise. Cette correction relève une donnée mobile → nécessite une source citée + validité datée, conforme au registre de constantes.

### DOUTEUX — corrections

- **`capital_tax.*` (33 clés : default_rate, married_discount, 5 brackets, 26 cantonal)** : remplacer le modèle « taux plat par canton » par une modélisation de la **progressivité par montant** (le fédéral art. 38 = 1/5 du barème art. 36 ; chaque canton a son propre barème progressif). À défaut d'implémenter 26 barèmes, publier au minimum des **taux effectifs par tranche de montant** (ex. @100k / @300k / @500k) issus d'une table citable (calculsuisse / VZ / administrations cantonales), avec `valid_from`/`valid_until` et un rappel de volatilité (réformes cantonales 2024-2026). Corriger l'attribution `capital_tax.default_rate → LIFD art. 38` (art. 38 ≠ 6,5 % plat).
- **`EFFECTIVE_RATES_100K_SINGLE` (LOT 2, 26 cantons)** : (1) trancher la contradiction label/code (cantonal+communal seul, sans double-compter l'IFD) et corriger le docstring ; (2) recalibrer sur une table officielle (ESTV « Charge fiscale en Suisse » / BAK Steuerbelastungsmonitor) — MINT sous-estime GE/VD/NE/BE et surestime ZG/ZH, ce qui compresse l'écart inter-cantonal ; (3) dater la validité.
- **`mortgage.amortization_rate` (0.01)** : documenter que la règle réelle est « amortir jusqu'à 2/3 de la valeur de nantissement en 15 ans » ; 1 %/an est une proxy — soit renommer/commenter, soit dériver le montant d'amortissement de la règle 2/3-en-15-ans plutôt que d'un taux plat.

### CONFORME (aucune correction de valeur, corriger seulement la traçabilité)

`mortgage.theoretical_rate`, `mortgage.maintenance_rate`, `mortgage.max_charge_ratio`, `mortgage.min_equity`, `mortgage.max_2nd_pillar` — valeurs correctes, mais remplir `valid_from`/`valid_until` et remplacer `source_url` générique par la directive ASB précise.

---

## Sources (récapitulatif)

- ASB directives financements hypothécaires (rév. 2025) — <https://www.finma.ch/fr/~/media/finma/dokumente/dokumentencenter/myfinma/4dokumentation/selbstregulierung/sbvg_rl_hypofinanzierungen_20231213.pdf> · <https://mendo.ch/fr/nouvelles-directives-sur-le-financement-hypothecaire-a-partir-de-2025/> · <https://www.vermoegenszentrum.ch/fr/competences/un-bien-foncier-doit-etre-financierement-supportable>
- IFD barème / progression à froid 2026 — <https://www.estv.admin.ch/fr/deductions-taux-baremes-impot-federal-direct> · <https://www.efd.admin.ch/fr/newnsb/VzaAUrhkPx2EPde4a6e3O> · <https://www.kursor.ch/impot-suisse>
- LIFD art. 38 (retrait capital, 1/5 art. 36) — recherche fedlex/ESTV/CSI
- Retrait capital effectifs par canton — <https://www.calculsuisse.ch/guides/imposition-retrait-capital-lpp-3a/> · <https://www.moneyland.ch/en/retirement-savings-withdrawal-tax-proposal-analysis-2025> · <https://www.klearconseils.ch/post/conseil-etats-bloque-hausse-impot-capital-lpp>
- Charge fiscale cantonale effective — <https://www.calculsuisse.ch/guides/impots-geneve-vaud-valais/> · <https://www.calculsuisse.ch/guides/charge-fiscale-26-cantons/> · BAK Zürcher Steuerbelastungsmonitor 2025
