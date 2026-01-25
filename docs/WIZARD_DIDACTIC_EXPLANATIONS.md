# Corrections & Explications Didactiques

## 1. Formulations Conditionnelles (Pas d'Absolus)

### ❌ AVANT (trop affirmatif)
```
"Le 3a te permet de déduire jusqu'à CHF 7'258/an de tes impôts."
```

### ✅ APRÈS (conditionnel + robuste)
```
"Le 3a permet de déduire jusqu'à CHF 7'258/an (2026, salarié) de tes impôts. 
Le plafond dépend de ton statut et des règles en vigueur."
```

### Règle Générale
**Toujours mentionner :**
- Année de référence (ex: "2026")
- Statut applicable (ex: "salarié", "indépendant sans 2e pilier")
- Variabilité (ex: "selon canton", "règles en vigueur")

---

## 2. Questions Sensibles : Explications + Option Refus

### Exemple : `q_international_complexity`

```dart
WizardQuestion(
  id: 'q_international_complexity',
  type: QuestionType.choice,
  category: QuestionCategory.tax,
  question: 'Revenus à l\'étranger / double résidence / nationalité US ?',
  
  // ✅ Explication claire du "pourquoi"
  subtitle: 'Pour activer un parcours prudent si ta situation fiscale est complexe.',
  
  // ✅ Explication détaillée (affichée si l'utilisateur clique sur "?")
  explanation: '''
Pourquoi cette question ?

Certaines situations (revenus étrangers, double résidence, nationalité US) 
nécessitent un accompagnement spécialisé car les règles fiscales sont plus 
complexes (ex: FATCA pour les citoyens US).

Mint adaptera ses conseils pour rester prudent et te recommandera de consulter 
un expert si nécessaire.

Cette info reste confidentielle et n'est jamais partagée.
  ''',
  
  tags: ['core', 'all', 'international', 'tax'],
  
  options: [
    QuestionOption(label: 'Oui', value: true, icon: 'public'),
    QuestionOption(label: 'Non', value: false, icon: 'close'),
    // ✅ Option "préférer ne pas répondre"
    QuestionOption(
      label: 'Préférer ne pas répondre', 
      value: null, 
      icon: 'block',
      description: 'Mint restera prudent sur les conseils fiscaux',
    ),
  ],
  
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
)
```

---

## 3. Explications Didactiques par l'Exemple

### Principe : "Show, Don't Tell"
Chaque concept doit être expliqué avec un **exemple concret** et **chiffré**.

---

### Exemple 1 : 3a (Pilier 3a)

```dart
WizardQuestion(
  id: 'q_has_3a',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'As-tu un compte 3e pilier (3a) ?',
  
  // ✅ Formulation conditionnelle selon statut
  subtitle: 'Le 3a permet de déduire de tes impôts (plafond selon statut et règles en vigueur).',
  
  // ✅ Explication didactique avec bifurcation selon statut
  explanation: '''
Le 3e pilier (3a), c'est quoi ?

C'est un compte d'épargne bloqué jusqu'à la retraite (ou achat logement) 
qui te permet de payer moins d'impôts chaque année.

📊 Exemple concret selon ton statut :

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 EMPLOYÉ avec caisse de pension (LPP)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Plafond 2026 : CHF 7'258/an

Exemple (canton VD, revenu CHF 80'000) :
• Verses CHF 7'258 en 2026
• Économie d'impôts estimée : ~CHF 1'800 (taux marginal ~25%)
• Coût réel : ~CHF 5'458

Projection 30 ans (scénarios pédagogiques) :
• Prudence (1%) : ~CHF 250'000
• Central (3%) : ~CHF 350'000
• Stress (5%) : ~CHF 500'000

Économies fiscales cumulées (30 ans) : ~CHF 54'000

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💼 INDÉPENDANT sans caisse de pension
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Plafond 2026 : jusqu'à 20% du revenu net, max CHF 36'288/an

Exemple (revenu net CHF 100'000) :
• Verses CHF 20'000 en 2026 (20% de CHF 100'000)
• Économie d'impôts estimée : ~CHF 6'000 (taux marginal ~30%)
• Coût réel : ~CHF 14'000

Projection 30 ans (scénarios pédagogiques) :
• Prudence (1%) : ~CHF 700'000
• Central (3%) : ~CHF 970'000
• Stress (5%) : ~CHF 1'330'000

Économies fiscales cumulées (30 ans) : ~CHF 180'000

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 Le 3a te "rembourse" une partie via les impôts (selon ton taux marginal) !

⚠️ Hypothèses et limites :
• Plafonds 2026 (changent chaque année)
• Taux marginaux estimés (varient selon canton/revenu/déductions)
• Projections : hypothèses pédagogiques, pas des promesses
• Rendements passés ne garantissent pas rendements futurs
• Déduction fiscale selon règles applicables à ta situation

📄 Info disponible sur ton certificat de salaire (ligne "Cotisations LPP")

🎯 Mint calculera ton plafond exact selon ton statut et ta situation
  ''',
  
  tags: ['core', 'all', 'pension'],
  required: true,
  allowSkip: false,
  
  options: [
    QuestionOption(label: 'Oui', value: true, icon: 'account_balance'),
    QuestionOption(label: 'Non', value: false, icon: 'close'),
  ],
  
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)
```

---

### Exemple 2 : Rachat LPP

```dart
WizardQuestion(
  id: 'q_peak_lpp_buyback',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'Rachat LPP déjà envisagé / possible ?',
  
  subtitle: 'Pour optimiser la fiscalité et augmenter ta rente future.',
  
  // ✅ Explication didactique avec formulation conditionnelle
  explanation: '''
Le rachat LPP, c'est quoi ?

C'est verser de l'argent dans ton 2e pilier (caisse de pension) pour :
1. Combler des lacunes (études longues, temps partiel, années à l'étranger)
2. Augmenter ta rente future
3. Réduire tes impôts l'année du rachat

📊 Exemple concret (canton VD, revenu CHF 100'000) :

• Tu rachètes CHF 15'000 en 2026
• Économie d'impôts estimée : ~CHF 4'500 (taux marginal ~30%)
• Coût réel : ~CHF 10'500

Impact retraite (scénarios pédagogiques, taux conversion 6%) :
• Prudence (taux 5%) : +CHF 750/an à vie (dès 65 ans)
• Central (taux 6%) : +CHF 900/an à vie
• Stress (taux 7%) : +CHF 1'050/an à vie

Retour sur investissement (scénario central) :
• ~12 ans de retraite pour "récupérer" le coût réel

💡 Le rachat LPP est en général déductible fiscalement, selon ta situation !

⚠️ Hypothèses et limites :
• Déduction fiscale selon règles applicables à ta situation
• Vérifier avec justificatifs (certificat LPP, déclaration fiscale)
• Taux de conversion LPP : hypothèse actuelle, peut baisser
• Délai de 3 ans avant retrait pour achat logement
• Règles spécifiques de ta caisse de pension

📄 Info disponible sur ton certificat LPP (ligne "Montant de rachat possible")

🎯 Mint t'aidera à évaluer si le rachat LPP est pertinent selon ta situation
  ''',
  
  tags: ['age_band:36-49', 'pension', 'fiscal'],
  conditions: ['age >= 36', 'age <= 49'],
  
  options: [
    QuestionOption(label: 'Oui', value: true, icon: 'trending_up'),
    QuestionOption(label: 'Non', value: false, icon: 'close'),
    QuestionOption(label: 'Je ne sais pas', value: null, icon: 'help'),
  ],
  
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)
```

---

### Exemple 3 : Fonds d'Urgence

```dart
WizardQuestion(
  id: 'q_single_emergency_fund',
  type: QuestionType.choice,
  category: QuestionCategory.cashflow,
  question: 'As-tu un plan "filet de sécurité" (épargne d\'urgence) ?',
  
  subtitle: 'Recommandé : 3-6 mois de charges fixes.',
  
  // ✅ Explication didactique avec scénarios
  explanation: '''
Le fonds d'urgence, c'est quoi ?

C'est une réserve d'argent facilement accessible pour faire face aux imprévus :
• Perte d'emploi
• Réparation urgente (voiture, logement)
• Frais médicaux non couverts
• Baisse de revenu temporaire

📊 Exemple concret (charges mensuelles CHF 3'500) :

Scénarios recommandés :
• Prudence (6 mois) : CHF 21'000
• Central (4-5 mois) : CHF 14'000 - CHF 17'500
• Stress (3 mois minimum) : CHF 10'500

Comparaison :

Sans fonds d'urgence :
• Perte d'emploi → Crédit conso à 8% → Spirale d'endettement
• Stress financier constant

Avec fonds d'urgence (scénario central, 4 mois) :
• Perte d'emploi → 4 mois de tranquillité pour chercher
• Pas de stress, pas de dettes
• Sérénité financière

💡 Le fonds d'urgence est la PRIORITÉ #1 avant tout investissement !

⚠️ Hypothèses et limites :
• Montant selon tes charges réelles
• Ajuster selon stabilité emploi (CDI vs CDD vs indépendant)
• Placer sur compte accessible (pas 3a/actions)

📄 Où le placer ?
• Compte épargne (0.5%) : accessible immédiatement
• Pas en actions/3a : trop risqué ou bloqué

🎯 Plan d'action selon ton épargne mensuelle :
• CHF 500/mois → Objectif 4 mois atteint en 28 mois
• CHF 1'000/mois → Objectif 4 mois atteint en 14 mois
• CHF 1'500/mois → Objectif 4 mois atteint en 9 mois
  ''',
  
  tags: ['household:single', 'safe_mode'],
  conditions: ['q_household_type == single'],
  
  options: [
    QuestionOption(label: 'Oui', value: true, icon: 'savings'),
    QuestionOption(label: 'Non', value: false, icon: 'warning'),
  ],
  
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)
```

---

### Exemple 4 : Hypothèque Taux Fixe

```dart
WizardQuestion(
  id: 'q_mortgage_fixed_end_date',
  type: QuestionType.date,
  category: QuestionCategory.housing,
  question: 'Échéance du taux fixe ?',
  
  subtitle: 'Mint te rappellera 120 jours avant pour renégocier.',
  
  // ✅ Explication didactique avec exemple
  explanation: '''
Pourquoi c'est important ?

Quand ton taux fixe arrive à échéance, tu dois renégocier avec ta banque.
C'est le moment de comparer les offres et potentiellement économiser des milliers de CHF.

📊 Exemple concret (hypothèque CHF 600'000, 10 ans) :

Scénario 1 : Tu renégocies 120 jours avant
• Taux actuel : 2.5%
• Nouveau taux négocié : 2.2% (comparaison de 3 banques)
• Économie : CHF 1'800/an → CHF 18'000 sur 10 ans

Scénario 2 : Tu oublies et la banque prolonge automatiquement
• Taux automatique : 2.8% (moins bon)
• Surcoût : CHF 1'800/an → CHF 18'000 sur 10 ans

💡 Mint te rappellera 120 jours avant pour :
1. Comparer les offres du marché
2. Négocier avec ta banque actuelle
3. Changer de banque si meilleure offre

⚠️ Délai recommandé : 90-180 jours avant échéance
(Les banques fixent leurs taux 3-6 mois à l'avance)

🎯 Info disponible sur ton contrat hypothécaire
  ''',
  
  hint: 'Mois/Année (ex: 06/2027)',
  tags: ['housing:owner', 'timeline'],
  conditions: ['q_mortgage_type == fixed'],
  
  createsTimelineItem: true,
  timelineRule: 'Rappel 120 jours avant: renégociation hypothèque',
  
  sensitivity: DataSensitivity.medium,
)
```

---

### Exemple 5 : Leasing vs Achat

```dart
WizardQuestion(
  id: 'q_has_leasing',
  type: QuestionType.choice,
  category: QuestionCategory.debt,
  question: 'Leasing véhicule ?',
  
  subtitle: 'Pour évaluer ton score de risque.',
  
  // ✅ Explication didactique avec exemple
  explanation: '''
Pourquoi on te demande ça ?

Le leasing est une charge fixe qui impacte ton budget et ton score de risque.
Mint veut s'assurer que tu as assez de marge pour tes autres objectifs.

📊 Exemple concret (leasing CHF 450/mois, 4 ans) :

Coût total leasing : CHF 21'600

Alternative : Achat d'occasion CHF 15'000
• Économie immédiate : CHF 6'600

Si tu investis ces CHF 6'600 à 5% pendant 20 ans :
• Capital final : CHF 17'500

💡 Un leasing te coûte ~CHF 17'500 en opportunité perdue !

⚠️ Quand le leasing a du sens :
• Voiture professionnelle (déductible)
• Besoin de flexibilité (changement fréquent)
• Budget serré (pas d'apport pour achat)

Quand éviter :
• Budget déjà tendu (dettes > 30% revenu)
• Pas de fonds d'urgence
• Objectif épargne/investissement prioritaire

🎯 Mint t'aidera à évaluer si le leasing est compatible avec tes objectifs
  ''',
  
  tags: ['core', 'all', 'debt', 'safe_mode'],
  
  options: [
    QuestionOption(label: 'Oui', value: true, icon: 'directions_car'),
    QuestionOption(label: 'Non', value: false, icon: 'close'),
  ],
  
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)
```

---

## 4. Pattern Général pour Explications

### Structure Recommandée

```
1. C'est quoi ? (définition simple)
2. Pourquoi c'est important ? (contexte)
3. Exemple concret (chiffré, canton/revenu spécifique)
4. Impact chiffré (économies, coûts, opportunités)
5. Conditions/Limites (⚠️)
6. Où trouver l'info (📄)
7. Action recommandée (🎯)
```

### Exemple de Template

```dart
explanation: '''
[CONCEPT], c'est quoi ?

[Définition simple en 1-2 phrases]

📊 Exemple concret ([canton], revenu CHF [X]) :

• [Action]
• [Impact immédiat]
• [Impact long terme]

💡 [Insight clé / règle d'or]

⚠️ Conditions/Limites :
• [Condition 1]
• [Condition 2]

📄 Info disponible sur [document/source]

🎯 Mint t'aidera à [action recommandée]
''',
```

---

## 5. Corrections Appliquées

### ✅ Toutes les questions avec montants
- Ajout année de référence (2026)
- Ajout statut applicable (salarié/indépendant)
- Mention "selon canton" si pertinent
- Mention "règles en vigueur"

### ✅ Toutes les questions sensibles
- Explication du "pourquoi"
- Option "préférer ne pas répondre"
- Mention confidentialité

### ✅ Tous les concepts complexes
- Explication didactique avec exemple
- Chiffres concrets
- Comparaison scénarios
- Conditions/limites

---

**Prêt à coder avec ces corrections** ! 🎯
