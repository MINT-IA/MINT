# Insert: q_canton_move (Demenagement cantonal)

## Metadata
```yaml
questionId: "q_canton_move"
phase: "Niveau 2"
status: "READY"
lifeEvent: "cantonMove"
```

## Trigger
- L'utilisateur indique un projet de demenagement dans un autre canton.
- Changement de canton dans le profil.
- Question sur les differences fiscales entre cantons.

## Inputs
- Canton actuel
- Canton cible
- Revenu imposable
- Situation familiale (celibataire, marie-e, avec enfants)
- Fortune imposable
- Proprietaire ou locataire

## Outputs
- Comparaison fiscale entre les deux cantons (impot sur le revenu + fortune).
- Difference de prime LAMal.
- Impact sur les allocations familiales.
- Estimation de l'economie ou du surcout annuel.

## Chiffre choc
"Un demenagement de Neuchatel a Zoug peut representer plus de CHF 15'000/an d'economie fiscale pour un revenu de CHF 120'000 -- mais les loyers sont aussi nettement plus eleves."

## Contenu educatif

### Fiscalite cantonale (LIFD + LHID)
La Suisse a 26 systemes fiscaux cantonaux differents, en plus de l'impot federal direct (LIFD). Les ecarts sont considerables :
- **Canton le plus taxe** (pour un revenu de 100k, celibataire) : Neuchatel, Bale-Ville, Vaud.
- **Canton le moins taxe** : Zoug, Schwyz, Nidwald, Appenzell Rhodes-Interieures.
- L'ecart peut atteindre un facteur 2 entre le canton le plus cher et le moins cher.

### Date determinante (LIFD art. 68)
C'est ton **domicile fiscal au 31 decembre** qui determine le canton d'imposition pour l'annee entiere. Si tu demenages en novembre, tu es impose-e dans le nouveau canton pour toute l'annee.

### Assurance maladie (LAMal)
Les primes LAMal varient fortement d'un canton a l'autre. Les differences peuvent atteindre CHF 200-400/mois par adulte. Apres un demenagement, tu disposes de **3 mois** pour changer de caisse ou adapter ta prime a la region.

### Allocations familiales (LAFam art. 3)
Chaque canton fixe le montant des allocations familiales. Elles vont de CHF 200/mois (minimum legal) a CHF 305/mois par enfant selon le canton. Un demenagement peut donc augmenter ou diminuer tes allocations.

### Deductions cantonales specifiques
Certains cantons offrent des deductions supplementaires (frais de garde, 3e pilier, frais de transport, deduction pour locataires) qui n'existent pas partout. Renseigne-toi sur les specificites du canton cible.

### Impot sur la fortune (LHID art. 13)
L'impot sur la fortune varie aussi enormement. Schwyz et Nidwald sont tres favorables, tandis que Geneve et Vaud appliquent des taux plus eleves. Si tu as un patrimoine important, c'est un facteur a ne pas negliger.

### Ce que tu peux faire
- Compare ta charge fiscale actuelle avec celle du canton cible dans le simulateur MINT.
- Verifie les primes LAMal dans la nouvelle region sur priminfo.admin.ch.
- Si tu es proprietaire, renseigne-toi sur l'impot sur la valeur locative dans le nouveau canton.
- Pense a annoncer ton demenagement a l'Office cantonal de la population dans les 14 jours.

## Hypothèses
- Comparaison basee sur les baremes cantonaux en vigueur et les taux communaux moyens.
- Deductions forfaitaires standard (pas de deductions personnalisees).
- Primes LAMal basees sur la region de primes du chef-lieu cantonal.

## Limites
- L'impot reel depend de la commune (multiplicateur communal variable).
- Les primes LAMal dependent de la region de primes exacte, pas seulement du canton.
- Le cout de la vie global (loyer, transports, garde d'enfants) n'est pas entierement modelise.
- Ne prend pas en compte les specificites fiscales communales.

## Disclaimer
"Estimation simplifiee a but educatif -- ne constitue pas un conseil fiscal. Les montants reels dependent de la commune, de la fortune et de nombreux facteurs individuels. Consulte un-e specialiste fiscal-e pour un calcul personnalise."

## Sources
- LIFD art. 68 (domicile fiscal au 31 decembre)
- LHID art. 3 (souverainete fiscale cantonale)
- LHID art. 13 (impot sur la fortune)
- LAMal art. 7 (obligation d'assurance par canton)
- LAFam art. 3, 5 (allocations familiales cantonales)
- OCP (Ordonnance sur le controle des habitants) -- annonce de demenagement

## Action
"Compare ta charge fiscale entre les deux cantons dans le simulateur MINT."

## Reminder
"31 decembre: ton domicile fiscal a cette date determine le canton d'imposition pour l'annee entiere."

## Safe Mode
Non concerne.
