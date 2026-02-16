# ROADMAP — ÉVÉNEMENTS DE VIE (Complet)

**Date** : 9 février 2026
**Statut** : Document de référence — couvre TOUS les événements de vie financièrement impactants en Suisse

---

## LISTE DÉFINITIVE : 18 ÉVÉNEMENTS DE VIE

> Réduit de 25 à 18 après audit. Principes appliqués :
> - Fusionner les doublons (séparation → divorce, adoption → birth, maladie → disability)
> - Déplacer les reminders (mortgageRenewal, leasingEnd, creditEnd) dans TimelineService
> - Chaque événement = impact financier unique + parcours utilisateur distinct

### Catégorie A — FAMILLE (5 événements)

| # | Événement | Impact CHF | LifeEventType | Statut | Sprint |
|---|-----------|-----------|---------------|--------|--------|
| A1 | **Concubinage** | 2-10k/an (zéro protection) | `concubinage` | L0 | S22+ |
| A2 | **Mariage** | 3-20k/an (fiscal) | `marriage` | L2 | S22 |
| A3 | **Naissance** | 15-25k/an | `birth` | L2 | S22 |
| A4 | **Divorce** | 50-500k total | `divorce` | L4 ✅ | S10 |
| A5 | **Décès d'un proche** | Variable | `deathOfRelative` | L4 ✅ | S10 |

*Fusionnés : séparation → divorce (même parcours juridique CH), adoption → birth (même impact financier), partenariat → marriage (fiscalité identique)*

### Catégorie B — PROFESSIONNEL (5 événements)

| # | Événement | Impact CHF | LifeEventType | Statut | Sprint |
|---|-----------|-----------|---------------|--------|--------|
| B1 | **Premier emploi** | Setup complet | `firstJob` | L4 ✅ | S19 |
| B2 | **Changement d'emploi** | 10-100k/an (LPP) | `newJob` | L4 ✅ | S9 |
| B3 | **Passage indépendant** | 30-100k/an | `selfEmployment` | L4 ✅ | S18 |
| B4 | **Perte d'emploi** | 20-80k total | `jobLoss` | L4 ✅ | S19 |
| B5 | **Retraite** | 200k-1M total | `retirement` | L2 | S21 |

*Fusionnés : incomeReduction → supprimé (pas un événement), earlyRetirement → retirement (même parcours, paramètre différent)*

### Catégorie C — PATRIMOINE (3 événements)

| # | Événement | Impact CHF | LifeEventType | Statut | Sprint |
|---|-----------|-----------|---------------|--------|--------|
| C1 | **Achat immobilier** | 100-500k total | `housingPurchase` | L2 | S17 |
| C2 | **Vente immobilier** | Variable | `housingSale` | L1 | S22+ |
| C3 | **Héritage reçu** | Variable | `inheritance` | L4 ✅ | S10 |

*Déplacés vers TimelineService (reminders) : mortgageRenewal, leasingEnd, creditEnd. Donation = reste en L1 dans C3.*

### Catégorie D — SANTÉ (1 événement)

| # | Événement | Impact CHF | LifeEventType | Statut | Sprint |
|---|-----------|-----------|---------------|--------|--------|
| D1 | **Invalidité** | 100-500k+ total | `disability` | L4 ✅ | S2 |

*Fusionnés : seriousIllness + workIncapacity → disability (continuum CO 324a → IJM → AI dans le droit suisse)*

### Catégorie E — MOBILITÉ (2 événements)

| # | Événement | Impact CHF | LifeEventType | Statut | Sprint |
|---|-----------|-----------|---------------|--------|--------|
| E1 | **Déménagement cantonal** | 5-30k/an (fiscal) | `cantonMove` | L4 ✅ | S20 |
| E2 | **Départ / Arrivée Suisse** | Variable | `countryMove` | L1 | S22+ |

*Fusionnés : countryArrival + countryDeparture + countryReturn → countryMove (direction = paramètre)*

### Catégorie F — CRISE (2 événements)

| # | Événement | Impact CHF | LifeEventType | Statut | Sprint |
|---|-----------|-----------|---------------|--------|--------|
| F1 | **Surendettement** | Prévention faillite | `debtCrisis` | L1 | S16 |
| F2 | **Donation** | Variable | `donation` | L1 | S22+ |

---

## DÉTAIL PAR ÉVÉNEMENT — CE QUE MINT DEVRAIT COUVRIR

### A1. Mise en ménage / Concubinage
**Impact financier** :
- PAS de splitting fiscal (contrairement aux mariés)
- PAS de rente de survivant AVS
- PAS d'héritage automatique (sauf testament)
- Clause bénéficiaire 3a : concubin non couvert par défaut
- RC ménage : adaptation assurance

**MINT devrait** :
- Alerter : "En concubinage, vous n'avez AUCUN droit automatique"
- Proposer : clause bénéficiaire 3a, testament, contrat de concubinage
- Simuler : différence marié vs concubin (impôts, héritage, AVS)
- Lien : notaire pour contrat de concubinage

### A2. Mariage
**Impact financier** :
- Splitting fiscal fédéral (bonus si revenus très différents, pénalité si similaires)
- Double plafond 3a (14'516 CHF/an si deux revenus)
- Rente AVS plafonnée à 150% de la rente max pour un couple
- Régime matrimonial par défaut : participation aux acquêts
- LPP : prestations de survivant automatiques
- Allocations familiales : un seul parent touche

**MINT devrait** :
- Simulateur "Bonus ou pénalité fiscale du mariage" par canton
- Checklist : mise à jour bénéficiaires, régime matrimonial, testament
- Optimisation couple : 2x 3a, stratégie LPP coordonnée
- Alerte : plafonnement rente AVS couple

### A4. Naissance / Adoption
**Impact financier** :
- Allocations familiales : 200-380 CHF/mois (varie par canton)
- Déductions fiscales : 6'600 CHF fédéral + cantonal (varie)
- Frais de garde déductibles : max 25'500 CHF (LIFD art. 33 al. 3)
- Congé maternité : 14 semaines, 80% du salaire (max 220 CHF/jour)
- Congé paternité : 2 semaines, 80% du salaire
- Impact temps partiel sur LPP (gender gap prévoyance)

**MINT devrait** :
- Calculateur allocations familiales par canton
- Simulateur impact temps partiel sur retraite (10/20/30 ans)
- Checklist post-naissance : assurance enfant, bénéficiaires, budget
- Warning gender gap si passage à temps partiel

### A7. Veuvage
**Impact financier** :
- Rente de veuf/veuve AVS : 80% de la rente du défunt (si conditions remplies)
- Capital décès LPP : selon règlement caisse
- 3a du défunt : versé selon clause bénéficiaire
- Retour au barème fiscal célibataire (perte du splitting)
- Succession : conjoint survivant = 50% en propriété + usufruit ou pleine propriété (CC)

**MINT devrait** :
- Calculateur "revenus post-décès conjoint" (AVS survivant + LPP + 3a)
- Checklist urgente : annonces (AVS, LPP, 3a, assurances, banques)
- Guidance succession avec notaire
- Adaptation budget au nouveau revenu

### B1. Premier emploi
**Impact financier** :
- Premier salaire, premières cotisations AVS/AI/APG/AC (5.3%)
- Affiliation LPP obligatoire dès 25 ans (cotisations dès seuil 22'050 CHF)
- Ouverture 3a possible dès revenu lucratif
- Sortie LAMal parents → propre franchise
- Première déclaration d'impôts

**MINT devrait** :
- Onboarding "Premier emploi" : comprendre sa fiche de salaire
- Guidance : ouvrir un 3a fintech dès le premier mois
- Warning : assurance 3a = piège pour jeunes
- Checklist : franchise LAMal, RC privée, 3a ouverture

### B5. Perte d'emploi / Chômage
**Impact financier** :
- Indemnités : 70% du gain assuré (80% si enfants, handicap, ou salaire < 3'797 CHF)
- Gain assuré max : 12'350 CHF/mois
- Durée : 200-520 indemnités selon âge et cotisations
- Délai cadre : 2 ans de cotisation dans les 2 ans précédents
- LPP : transfert en libre passage obligatoire après 30 jours
- 3a : pas de versement sans revenu lucratif
- Délai d'attente : 5 jours (général) + variable selon situation

**MINT devrait** :
- Calculateur indemnités chômage (montant, durée, délai)
- Timeline : inscription ORP (immédiate), libre passage (30j), 3a (pause)
- Checklist : documents nécessaires, droits, obligations
- Budget mode survie : dépenses minimales
- Lien : ORP cantonal

### B8-B9. Retraite (anticipée / normale / ajournée)
**Impact financier** :
- AVS anticipée : réduction de 6.8% par année (max 2 ans avant 65)
- AVS ajournée : supplément de 5.2% à 31.5% (1 à 5 ans après 65)
- LPP : rente viagère ou capital (ou mixte)
- 3a : retrait échelonné sur 5 ans (optimisation fiscale)
- Déménagement avant retraite : optimisation canton fiscal
- Prestations complémentaires si revenu insuffisant

**MINT devrait** :
- Simulateur AVS : anticipation vs ajournement (breakeven)
- Stratégie de retrait optimale : ordre 3a → LPP → AVS
- Optimisation cantonale : impact déménagement pré-retraite
- Calculateur prestations complémentaires
- Timeline 10 ans : rachats LPP, ouverture comptes 3a, échelonnement

### C1. Déménagement intercantonal
**Impact financier** : MASSIF et sous-estimé
- Impôt sur le revenu : variation de -40% à +40% selon canton
- Impôt ecclésiastique : 0 à 10% selon canton et sortie d'Église
- Impôt sur la fortune : variation extrême (NW vs GE)
- Multiplicateur communal : varie de 50% à 180%
- LAMal : primes différentes par canton (+/- 30%)
- Allocations familiales : montants cantonaux
- Si propriétaire : impôt sur gain immobilier à la vente

**MINT devrait** :
- Simulateur "Déménagement fiscal" : comparaison canton actuel vs nouveau
- Top 5 communes les moins chères fiscalement (par profil)
- Impact LAMal : différence de prime
- Checklist : annonces, changement plaques, assurances
- Alerte : "Un déménagement VD→ZH t'économise X CHF/an"

### C2. Achat immobilier
**Impact financier** :
- Fonds propres : 20% minimum (dont max 10% du 2e pilier)
- EPL : retrait 3a + LPP pour financer l'apport
- Hypothèque : capacité = charges ≤ 33% du revenu brut
- Charges : intérêts + amortissement + entretien (1% valeur/an)
- Valeur locative : revenu fictif imposable
- Déductions : intérêts hypothécaires + frais d'entretien
- Amortissement indirect via 3a : versement 3a → nanti à la banque

**MINT devrait** :
- Calculateur capacité d'achat (revenu, fonds propres, charges)
- Simulateur EPL : retrait optimal 3a vs LPP
- Comparaison SARON vs taux fixe (3/5/10 ans)
- Calculateur valeur locative + déductions
- Stratégie amortissement direct vs indirect
- Checklist acheteur : 15 étapes clés

### E1. Arrivée en Suisse
**Impact financier** :
- Affiliation LAMal obligatoire dans les 3 mois
- Impôt à la source (permis B/L)
- LPP : affiliation dès contrat de travail
- 3a : ouverture possible dès revenu lucratif suisse
- Transfert droits AVS : accords bilatéraux UE/AELE
- Reconnaissance qualifications professionnelles

**MINT devrait** :
- Onboarding "Nouvel arrivant" : 10 étapes financières
- Checklist : LAMal (3 mois), compte bancaire, NPA, impôts
- Explication impôt à la source vs déclaration ordinaire
- Guidance 3a : "Commence immédiatement, même petit montant"
- Calculateur rectification impôt source (si > 120k CHF)

### E2. Départ de Suisse
**Impact financier** :
- LPP : retrait total (hors UE/AELE) ou surobligatoire seul (UE/AELE)
- 3a : retrait obligatoire, impôt à la source (canton dernier domicile)
- AVS : rente exportable (avec accords bilatéraux) ou remboursement (hors accords)
- Impôt de départ : imposition dans canton de dernier domicile
- Stratégie : déménager dans canton fiscal avantageux AVANT le départ

**MINT devrait** :
- Checklist départ : ordre des opérations (canton → 3a → LPP → AVS)
- Simulateur impôt retrait capital (par canton de dernier domicile)
- Guidance UE/AELE vs reste du monde
- Optimisation : "Déménage à Schwyz avant de partir = -X% d'impôt"

### F1. Surendettement
**Impact financier** : Critique — risque de spirale
- Seuil d'alerte : charges dette > 30% du revenu net
- Office des poursuites : commandement de payer → saisie → acte de défaut de biens
- Minimum vital (LP) : insaisissable (varie par canton)
- Impact crédit futur : 5-20 ans selon gravité
- Implications LPP : avoir LPP insaisissable (sauf EPL)

**MINT devrait** :
- Diagnostic ratio dette/revenu avec code couleur
- Liens directs :
  - Dettes Conseils Suisse : www.dettes.ch
  - Caritas : www.caritas.ch/dettes
  - 26 services cantonaux de désendettement
- Planificateur remboursement : stratégie boule de neige vs avalanche
- Safe Mode renforcé : bloquer TOUTE recommandation d'investissement
- Information : minimum vital insaisissable
- Prévention : scoring comportemental amélioré

---

## MATRICE COUVERTURE — 18 ÉVÉNEMENTS DÉFINITIFS

```
Événement                Enum  Delta-Q  Simulator  Guidance  Niveau  Sprint
──────────────────────────────────────────────────────────────────────────────
A1 Concubinage            ❌     ❌        ❌         ❌       L0     S22+
A2 Mariage                ✅     ✅        ❌         ❌       L2     S22
A3 Naissance              ✅     ✅        ❌         ❌       L2     S22
A4 Divorce                ✅     ✅        ✅         ✅       L4 ✅  S10
A5 Décès proche           ✅     ✅        ✅         ✅       L4 ✅  S10

B1 Premier emploi         ✅     ✅        ✅         ✅       L4 ✅  S19
B2 Changement emploi      ✅     ✅        ✅         ✅       L4 ✅  S9
B3 Passage indépendant    ✅     ✅        ✅         ✅       L4 ✅  S18
B4 Perte emploi           ✅     ✅        ✅         ✅       L4 ✅  S19
B5 Retraite               ❌     ❌        ⚠️         ❌       L2     S21

C1 Achat immobilier       ✅     ✅        ❌         ❌       L2     S17
C2 Vente immobilier       ✅     ❌        ❌         ❌       L1     S22+
C3 Héritage               ✅     ✅        ✅         ✅       L4 ✅  S10

D1 Invalidité             ✅     ❌        ✅         ✅       L4 ✅  S2

E1 Déménagement cantonal  ✅     ✅        ✅         ✅       L4 ✅  S20
E2 Mobilité internationale ❌    ❌        ⚠️         ❌       L1     S22+

F1 Surendettement         ❌     ❌        ❌         ❌       L1     S16
F2 Donation               ✅     ❌        ❌         ❌       L1     S22+
──────────────────────────────────────────────────────────────────────────────
SCORE : 9/18 à L4 (50%)     Cible S22 : 12/18 à L3+ (67%)
```

Légende : ⚠️ = couvert partiellement dans un autre module

---

## ARCHITECTURE TECHNIQUE CIBLE

### LifeEventType enum (définitif — 18 types)

```dart
enum LifeEventType {
  // A — Famille (5)
  concubinage,       // Mise en ménage — zéro protection automatique
  marriage,          // Mariage + partenariat enregistré (même fiscalité)
  birth,             // Naissance + adoption (même impact financier)
  divorce,           // Divorce + séparation (même parcours juridique CH)
  deathOfRelative,   // Décès conjoint/proche — succession + veuvage

  // B — Professionnel (5)
  firstJob,          // Premier emploi — onboarding financier complet
  newJob,            // Changement d'emploi — comparaison LPP
  selfEmployment,    // Passage indépendant — perte couverture obligatoire
  jobLoss,           // Perte emploi — indemnités LACI
  retirement,        // Retraite (anticipée/normale/ajournée)

  // C — Patrimoine (3)
  housingPurchase,   // Achat immobilier — capacité, EPL, hypothèque
  housingSale,       // Vente immobilier — impôt gain immobilier
  inheritance,       // Héritage reçu + donation

  // D — Santé (1)
  disability,        // Invalidité (absorbe maladie + incapacité)

  // E — Mobilité (2)
  cantonMove,        // Déménagement intercantonal — impact fiscal massif
  countryMove,       // Arrivée / Départ / Retour Suisse

  // F — Crise (2)
  debtCrisis,        // Surendettement — Caritas, remboursement
  donation,          // Donation faite/reçue — implications fiscales
}

// DÉPLACÉS vers TimelineService (reminders, pas événements de vie) :
// mortgageRenewal, leasingEnd, creditEnd → RecurringEvent
```

**Pourquoi 18 et pas 32 ?**
- Chaque type = un parcours utilisateur DISTINCT avec des calculs UNIQUES
- Les variantes (anticipée/ajournée, arrivée/départ) = paramètres, pas types séparés
- Les reminders récurrents ≠ événements de vie ponctuels

### Niveau d'implémentation par événement

Chaque événement devrait avoir 4 niveaux :

| Niveau | Contenu | Effort |
|--------|---------|--------|
| **L1 — Enum + Label** | Type défini, label FR/DE | 1h |
| **L2 — Delta Questions** | 3-6 questions adaptatives post-événement | 2h |
| **L3 — Simulateur** | Calculs déterministes + résultats chiffrés | 1-3 jours |
| **L4 — Guidance complète** | Checklist, timeline, liens, alertes, éducation | 2-5 jours |

### Priorisation d'implémentation

**Tier 1 — Impact maximal (L3+L4 requis)** :
- Déménagement cantonal (simulateur fiscal comparatif)
- Achat immobilier (capacité + EPL + hypothèque)
- Perte emploi (indemnités LACI)
- Retraite (anticipation/ajournement AVS)
- Premier emploi (onboarding financier)
- Surendettement (Caritas + remboursement)

**Tier 2 — Impact élevé (L2+L3 suffisant)** :
- Mariage (bonus/pénalité fiscal)
- Naissance (allocations + temps partiel)
- Passage indépendant (cotisations AVS complètes)
- Arrivée/Départ Suisse
- Veuvage

**Tier 3 — Impact modéré (L2 suffisant)** :
- Concubinage, partenariat enregistré
- Reconversion, promotion
- Vente immobilier, donation

---

## NOTIFICATIONS INTELLIGENTES — MATRICE COMPLÈTE

### Par tranche d'âge (AgeBand)

| Âge | Événements les plus probables | Notification type |
|-----|-------------------------------|-------------------|
| 18-25 | Premier emploi, concubinage, arrivée CH | "Bienvenue dans la vie active. Tes 3 priorités..." |
| 26-35 | Mariage, naissance, achat immo, changement job | "Projet immobilier ? Vérifie ta capacité en 2 min" |
| 36-49 | Promotion, divorce, reconversion, héritage | "Tes revenus augmentent. Rachetons du LPP ?" |
| 50-65 | Pré-retraite, décès proche, veuvage | "Retraite dans X ans. Ton plan de retrait optimal..." |
| 65+ | Retraite, ajournement, veuvage | "Tes droits aux prestations complémentaires..." |

### Saisonnières (récurrentes)

| Mois | Notification |
|------|-------------|
| Janvier | "Bonne année ! Vérifie tes bénéficiaires 3a/LPP" |
| Mars | "Déclaration d'impôts : as-tu toutes tes déductions ?" |
| Juin | "Mi-année : es-tu dans les temps pour ton 3a ?" |
| Septembre | "Franchise LAMal : change avant le 30 novembre" |
| Novembre | "Dernière ligne droite : rachat LPP + 3a avant le 31 déc" |
| Décembre | "Dernier jour 3a ! Verse maintenant, économise X CHF" |

### Proactives (basées sur profil)

| Condition détectée | Notification |
|-------------------|-------------|
| Age 24 + pas de 3a | "Tu as 24 ans et pas de 3a. Chaque année perdue = X CHF à la retraite" |
| Concubin + pas de testament | "En concubinage, ton partenaire n'hérite de RIEN sans testament" |
| Propriétaire + hypothèque fin dans < 180j | "Ton taux fixe se termine bientôt. Compare les offres maintenant" |
| Indépendant + pas de IJM | "ALERTE : tu n'as aucune couverture perte de gain" |
| Revenus > 120k + impôt source | "Tu pourrais demander une rectification avantageuse" |
| Dettes > 30% revenus | "Ton ratio d'endettement est élevé. Besoin d'aide ?" |
| 10 ans avant retraite + 1 seul compte 3a | "Ouvre 2 comptes 3a supplémentaires pour échelonner" |

---

## PLANNING D'IMPLÉMENTATION — ÉVÉNEMENTS DE VIE

### Phase actuelle : 50% de couverture (post-S20)
- 9 événements à L4 : divorce, succession, invalidité, changement emploi, indépendant, premier emploi, perte emploi, déménagement cantonal, héritage
- 2 événements à L2 : mariage, naissance, achat immo, retraite
- 7 événements à L0-L1 : concubinage, vente immo, mobilité internationale, surendettement, donation

### Cible : 70% de couverture (6 mois)
- 12 événements à L3-L4
- 10 événements à L2
- 10 événements à L1

### Cible : 90% de couverture (12 mois)
- 20 événements à L3-L4
- 8 événements à L2
- 4 événements à L1

---

**Priorité** : Intégrer les événements de vie Tier 1 dans les sprints S16-S22
**Impact estimé** : +60% engagement, +40% rétention, différenciation marché totale
