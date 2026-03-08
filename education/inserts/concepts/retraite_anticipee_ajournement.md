# Insert: retraite_anticipee_ajournement (Retraite anticipée ou ajournée)

## Metadata
```yaml
questionId: "retraite_anticipee_ajournement"
phase: "Niveau 1"
status: "READY"
pilier: 1
concept: "retraite_anticipee_ajournement"
```

## Trigger
- L'utilisateur a plus de 58 ans.
- L'utilisateur mentionne une retraite anticipée ou demande quand partir à la retraite.
- La simulation MINT détecte un écart entre l'âge de retraite souhaité et 65 ans.

## Chiffre Choc
"Partir 2 ans plus tôt que prévu réduit ta rente AVS de 13.6% — à vie. Sur 20 ans de retraite, c'est plus de CHF 50'000 de rente en moins (selon ta rente individuelle)."

## Niveau 0
Imagine ta rente AVS comme un robinet avec des crans. À 65 ans, le robinet est en position standard. Si tu ouvres le robinet plus tôt, la pression est plus faible — un cran en moins par année d'anticipation, et ça reste à ce niveau pour toujours. Si tu attends après 65 ans pour ouvrir le robinet, la pression monte — un cran en plus par année d'attente.

La différence fondamentale : le cran n'est pas récupérable. Que tu vives encore 10 ans ou 30 ans, le robinet reste à la même pression choisie au départ.

Limite de l'analogie : le robinet ne tient pas compte de combien tu as "économisé" pendant les années supplémentaires de travail. En réalité, les cotisations versées après 65 ans pendant un ajournement ne comptent plus pour augmenter la rente — elles sont perdues pour toi (mais pas pour le système).

## Niveau 1
**Anticipation** (LAVS art. 40) :
- Possible dès **63 ans** (femmes et hommes depuis la réforme AVS 21 en vigueur 2024).
- Réduction : **6.8% de la rente par année d'anticipation**.
  - 1 an d'anticipation = −6.8%
  - 2 ans d'anticipation = −13.6% (définitif, à vie)
- Pendant la période d'anticipation, les cotisations AVS restent dues si tu travailles.

**Ajournement** (LAVS art. 39) :
- Possible jusqu'à **70 ans** (5 ans d'ajournement maximum).
- Majoration progressive :
  - 1 an : +5.2%
  - 2 ans : +10.8%
  - 3 ans : +17.1%
  - 4 ans : +24.0%
  - 5 ans : +31.5%
- Les cotisations versées durant l'ajournement n'améliorent plus la rente (elles s'arrêtent d'être prises en compte).

Exemple comparé (rente de base : CHF 2'520/mois) :
| Scénario | Rente mensuelle |
|----------|----------------|
| Départ à 63 ans (−13.6%) | CHF 2'177/mois |
| Départ à 65 ans (standard) | CHF 2'520/mois |
| Départ à 67 ans (+10.8%) | CHF 2'792/mois |
| Départ à 70 ans (+31.5%) | CHF 3'314/mois |

Le 2e pilier suit ses propres règles d'anticipation (souvent dès 58 ans selon le règlement de caisse) et d'ajournement (jusqu'à 70 ans pour les indépendants affiliés volontairement).

## Sources
- LAVS art. 40 (anticipation de la rente, réduction de 6.8%/an)
- LAVS art. 39 (ajournement de la rente, majoration 5.2% à 31.5%)
- Réforme AVS 21 (entrée en vigueur 2024 — harmonisation âge de référence 65 ans)

## Action
"Simule les scénarios retraite à 63, 65 et 67 ans dans MINT pour voir l'impact en CHF/mois sur ta rente — selon ta situation, l'écart peut représenter plusieurs centaines de francs par mois à vie."

## Disclaimer
"Information à caractère éducatif, ne constitue pas un conseil en prévoyance au sens de la LSFin. Les taux d'anticipation et d'ajournement peuvent évoluer selon les réformes légales. Consulte un·e spécialiste pour ta situation personnelle avant toute décision irrévocable."
