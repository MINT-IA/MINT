# Insert: q_job_loss (Perte d'emploi / Chomage)

## Metadata
```yaml
questionId: "q_job_loss"
phase: "Niveau 1"
status: "READY"
lifeEvent: "jobLoss"
```

## Trigger
- L'utilisateur declare avoir perdu son emploi ou etre au chomage.
- Question sur les indemnites chomage, la duree des droits ou l'impact sur la prevoyance.
- Changement de statut professionnel vers "sans emploi".

## Inputs
- Age actuel
- Duree de cotisation AC (en mois)
- Dernier salaire brut annuel
- Charges de famille (oui/non)
- Canton de domicile

## Outputs
- Nombre maximal d'indemnites journalieres (200, 400 ou 520 jours).
- Montant mensuel estime de l'indemnite chomage.
- Delai-cadre de cotisation et delai-cadre d'indemnisation.
- Impact sur la prevoyance (LPP, AVS, 3a).
- Actions prioritaires a entreprendre.

## Chiffre choc
"Un salarie de 56 ans avec 22 mois de cotisation a droit a 520 indemnites journalieres -- soit environ 2 ans d'indemnisation. Mais un jeune avec moins de 12 mois de cotisation peut n'avoir droit qu'a 200 jours."

<!-- compliance:allow -->
## Contenu educatif

### Niveau 0 — L'essentiel en 30 secondes
L'assurance-chomage (AC) te verse une indemnite si tu perds ton emploi sans faute de ta part. Le montant correspond a **70% de ton dernier salaire assure** (80% si tu as des enfants a charge ou un bas revenu). La duree depend de ton age et de ta periode de cotisation.

### Niveau 1 — Comprendre tes droits

#### Conditions d'ouverture (LACI art. 8)
Pour avoir droit aux indemnités, il faut :
1. Etre domicilie-e en Suisse.
2. Avoir cotise au moins **12 mois** durant les 2 dernieres annees (delai-cadre de cotisation, LACI art. 9).
3. Etre apte au placement (disponible et capable de travailler).
4. Etre inscrit-e aupres de l'ORP (Office regional de placement).

#### Delai-cadre (LACI art. 9)
- **Delai-cadre de cotisation** : les 2 annees precedant l'inscription au chomage. Il faut avoir cotisé au moins 12 mois dans cette période.
- **Delai-cadre d'indemnisation** : 2 ans a partir de ton inscription. Tes indemnites doivent etre epuisees dans ce delai, sinon elles sont perdues.

#### Duree des indemnites (LACI art. 27 al. 2)
Le nombre maximal d'indemnites journalieres depend de ta periode de cotisation et de ton age :

| Situation | Indemnites journalieres |
|-----------|------------------------|
| Moins de 12 mois de cotisation (cas liberatoire) | **200 jours** |
| 12 mois ou plus de cotisation, age < 55 ans | **400 jours** |
| 12 mois ou plus de cotisation, age >= 55 ans | **520 jours** |

**Attention** : les indemnites sont versees par jour ouvrable (5 jours/semaine). 400 indemnites journalieres correspondent donc a environ **18 mois** d'indemnisation (400 / 22 jours ouvrables par mois).

#### Montant de l'indemnite (LACI art. 22)
- **Taux standard** : 70% du gain assure.
- **Taux majore** : 80% du gain assure si tu as des enfants a charge, si ton indemnite journaliere est inferieure a CHF 140, ou si tu es en incapacite de travail partielle.
- **Gain assure maximal** : CHF 148'200/an (LACI art. 3). Tout salaire au-dessus de ce plafond n'est pas couvert.
- **Gain assure** = ton salaire moyen des 6 ou 12 derniers mois (le plus avantageux), plafonné a CHF 148'200.

#### Delai d'attente (LACI art. 18)
Avant le premier versement, un **delai d'attente** s'applique (generalement 5 jours ouvrables). Ce delai peut etre plus long si tu n'as pas de charges de famille et que ton gain assure est eleve.

### Impact sur la prevoyance

#### LPP (2e pilier)
- A la fin de ton contrat de travail, ton avoir LPP est transfere sur un **compte de libre passage**.
- Tu n'accumules plus de bonifications de vieillesse (epargne) tant que tu n'as pas de nouvel employeur.
- Tu restes couvert-e pour les risques deces et invalidite via la fondation institution suppletive (pendant 6 mois max apres la sortie, selon LPP art. 10 al. 3).

#### AVS (1er pilier)
- Les indemnites chomage sont soumises aux cotisations AVS. Tu continues donc a cotiser et a accumuler des annees de cotisation.
- **Bonne nouvelle** : une periode de chomage indemnisee ne cree pas de lacune AVS.

#### 3e pilier (3a)
- Tu peux continuer a cotiser au 3a tant que tu percois des indemnites chomage (elles sont considerees comme un revenu soumis a l'AVS).
- Plafond annuel : **CHF 7'258** si tu etais affilie-e a une caisse de pension.

### Ce que tu peux faire
1. **Inscris-toi a l'ORP** des que possible (meme avant la fin de ton contrat).
2. **Verifie ton compte de libre passage** : ton avoir LPP doit etre transfere dans les 6 mois.
3. **Continue a cotiser au 3a** si ta situation financiere le permet (deduction fiscale maintenue).
4. **Fais le point sur tes annees AVS** : demande un extrait de compte sur ahv-iv.ch.
5. **Etablis un budget d'urgence** : base-toi sur 70% de ton dernier salaire net.

## Hypothèses
- Taux d'indemnite standard de 70% (80% avec charges de famille).
- Gain assure plafonné a CHF 148'200/an (LACI art. 3).
- Delai-cadre de 2 ans pour la cotisation et l'indemnisation.
- Durees basees sur la LACI art. 27 al. 2 (version en vigueur 2025/2026).

## Limites
- Le calcul ne prend pas en compte les situations particulieres (independant-e devenu-e salarie-e, frontalier-e, chomage partiel).
- Les cas de liberation de cotisation (maladie, maternite, service militaire) ne sont pas detailles ici.
- Le delai d'attente exact depend de la situation personnelle (gain assure, charges de famille).
- Les indemnites en cas de faute (licenciement pour faute grave) sont reduites ou suspendues (LACI art. 30).

## Disclaimer
"Estimation simplifiee a but educatif -- ne constitue pas un conseil juridique ou en prevoyance. Les montants et durees reels dependent de ta situation individuelle, de ta caisse de chomage et de ton ORP. Consulte ton conseiller-e ORP pour un calcul personnalise."

## Sources
- LACI art. 8 (conditions d'ouverture du droit)
- LACI art. 9 (delai-cadre de cotisation et d'indemnisation)
- LACI art. 13 (periode de cotisation minimale)
- LACI art. 18 (delai d'attente)
- LACI art. 22 (taux d'indemnite : 70% / 80%)
- LACI art. 23 (gain assure)
- LACI art. 27 al. 2 (nombre maximal d'indemnites journalieres : 200, 400, 520)
- LACI art. 3 (plafond du salaire assure : CHF 148'200)
- LACI art. 30 (suspension du droit a l'indemnite)
- LPP art. 10 al. 3 (couverture risque apres sortie)
- OPP3 art. 7 (plafond 3a salarie-e)

<!-- compliance:end -->

## Action
"Simule ton budget chomage et verifie l'impact sur ta prevoyance dans l'outil MINT."

## Reminder
"Jour 1 : Inscris-toi a l'ORP. Mois 1 : Transfere ton avoir LPP en libre passage. Mois 6 : Fais le bilan de ta recherche et ajuste ta strategie."

## Safe Mode
Si dette critique detectee : le desendettement est prioritaire. En cas de perte d'emploi avec des dettes, contacte un service de conseil en desendettement (Caritas, CSP) avant d'optimiser la prevoyance.
